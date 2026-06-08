"""Food at Peace — Claude vision proxy (AWS Lambda).

Holds the Anthropic API key server-side so it never ships inside the app. The
client POSTs a base64 food photo; this function builds the Anthropic Messages
request (forcing the ``log_food`` tool), calls Anthropic, and returns the flat
tool input as JSON — exactly the shape ``FoodAnalysis.fromToolInput`` expects.

Only the standard library plus boto3 are used; both are present in the Lambda
Python runtime, so there is nothing to bundle. boto3 is imported lazily so unit
tests can run without it (they stub out secret lookup).
"""

import base64
import hmac
import json
import os
import urllib.error
import urllib.request

# --- Configuration (from the SAM template's environment) ---------------------
MODEL = os.environ.get("MODEL", "claude-sonnet-4-6")
ANTHROPIC_KEY_PARAM = os.environ.get(
    "ANTHROPIC_KEY_PARAM", "/food-at-peace/anthropic-api-key"
)
APP_TOKEN_PARAM = os.environ.get("APP_TOKEN_PARAM", "/food-at-peace/app-token")

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
TOOL_NAME = "log_food"
MAX_TOKENS = 1024

# Prompts mirror lib/src/data/claude_vision_client.dart so both paths behave
# identically.
SYSTEM_PROMPT = (
    "You are a nutrition estimator. Look at the food photo and estimate the "
    "nutrition for the ENTIRE portion visible. Use typical recipes and serving "
    "sizes, and be realistic. If unsure about the portion, state your "
    "assumption in portionDescription and lower your confidence. Always call "
    "the log_food tool with your best numeric estimate; never refuse to "
    "estimate just because you cannot be exact."
)
USER_PROMPT = (
    "Estimate the calories, protein, and saturated fat for the food in this "
    "photo, then call log_food."
)

# Secrets are fetched once per cold start and cached here.
_secrets = {}
_ssm = None


class ProxyError(Exception):
    """An error to surface to the client with a chosen status + safe message."""

    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def _ssm_client():
    global _ssm
    if _ssm is None:
        import boto3  # lazy: keeps the module importable without boto3 in tests

        _ssm = boto3.client("ssm")
    return _ssm


def _get_secret(name):
    if name not in _secrets:
        resp = _ssm_client().get_parameter(Name=name, WithDecryption=True)
        _secrets[name] = resp["Parameter"]["Value"]
    return _secrets[name]


def _header(event, name):
    """Case-insensitive header lookup (API Gateway lowercases keys, but local
    invocations may not)."""
    headers = event.get("headers") or {}
    name = name.lower()
    for key, value in headers.items():
        if key.lower() == name:
            return value
    return None


def build_request_body(base64_image, media_type, model):
    """Port of buildRequestBody in claude_vision_client.dart. The system block is
    cache_control'd so prompt caching works just like the direct client."""
    return {
        "model": model,
        "max_tokens": MAX_TOKENS,
        "system": [
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        "tools": [
            {
                "name": TOOL_NAME,
                "description": (
                    "Record the nutrition estimate for the food shown in the "
                    "image."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": (
                                'Short name of the dish, e.g. "Chicken Caesar '
                                'salad".'
                            ),
                        },
                        "items": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Main components you identified.",
                        },
                        "calories": {
                            "type": "number",
                            "description": (
                                "Estimated total calories (kcal) for the full "
                                "portion shown."
                            ),
                        },
                        "proteinG": {
                            "type": "number",
                            "description": (
                                "Estimated grams of protein for the full "
                                "portion."
                            ),
                        },
                        "satFatG": {
                            "type": "number",
                            "description": (
                                "Estimated grams of saturated fat for the full "
                                "portion."
                            ),
                        },
                        "portionDescription": {
                            "type": "string",
                            "description": (
                                'The portion size you assumed, e.g. "1 bowl '
                                '(~350 g)".'
                            ),
                        },
                        "confidence": {
                            "type": "string",
                            "enum": ["low", "medium", "high"],
                            "description": "Your confidence in this estimate.",
                        },
                        "notes": {
                            "type": "string",
                            "description": "Optional caveats or assumptions.",
                        },
                    },
                    "required": [
                        "name",
                        "calories",
                        "proteinG",
                        "satFatG",
                        "portionDescription",
                        "confidence",
                    ],
                },
            }
        ],
        "tool_choice": {"type": "tool", "name": TOOL_NAME},
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": base64_image,
                        },
                    },
                    {"type": "text", "text": USER_PROMPT},
                ],
            }
        ],
    }


def parse_tool_input(response):
    """Port of parseFoodAnalysis: pull the forced log_food tool input out of a
    Messages response."""
    content = response.get("content")
    if isinstance(content, list):
        for block in content:
            if (
                isinstance(block, dict)
                and block.get("type") == "tool_use"
                and block.get("name") == TOOL_NAME
                and isinstance(block.get("input"), dict)
            ):
                return block["input"]
    raise ProxyError(502, "Couldn't read the estimate. Try another photo.")


def _map_anthropic_error(status, raw_body):
    """Turn an Anthropic HTTP error into a client-facing ProxyError. Messages
    never imply the *user* did something wrong on the proxy path — they have no
    key — and server-side key/credit problems are reported as a 502."""
    if status == 413:
        return ProxyError(413, "That image is too large. Try another photo.")
    if status == 429:
        return ProxyError(
            429, "Too many requests — please wait a moment and try again."
        )
    if status in (401, 403):
        return ProxyError(
            502, "Photo analysis is unavailable right now. Please try again later."
        )
    if status >= 500:
        return ProxyError(502, "Analysis service error — please try again shortly.")
    message = "Photo analysis failed. Please try again."
    try:
        err = json.loads(raw_body).get("error")
        if isinstance(err, dict) and isinstance(err.get("message"), str):
            message = err["message"]
    except (ValueError, TypeError, AttributeError):
        pass
    return ProxyError(status, message)


def _call_anthropic(api_key, body):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        ANTHROPIC_URL,
        data=data,
        headers={
            "content-type": "application/json",
            "anthropic-version": ANTHROPIC_VERSION,
            "x-api-key": api_key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise _map_anthropic_error(exc.code, raw)
    except urllib.error.URLError:
        raise ProxyError(502, "Analysis service error — please try again shortly.")


def _authorize(event):
    provided = _header(event, "x-app-token")
    expected = _get_secret(APP_TOKEN_PARAM)
    if not provided or not hmac.compare_digest(provided, expected):
        raise ProxyError(
            401, "Photo analysis is unavailable right now. Please try again later."
        )


def _parse_body(event):
    raw = event.get("body")
    if raw is None:
        raise ProxyError(400, "Empty request.")
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        raise ProxyError(400, "Invalid request body.")


def _response(status, body):
    # CORS headers are added by the HTTP API gateway (CorsConfiguration), so the
    # function only returns the payload.
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        _authorize(event)
        body = _parse_body(event)
        image = body.get("image")
        media_type = body.get("mediaType") or "image/jpeg"
        if not isinstance(image, str) or not image:
            raise ProxyError(400, "No image provided.")

        api_key = _get_secret(ANTHROPIC_KEY_PARAM)
        anthropic_response = _call_anthropic(
            api_key, build_request_body(image, media_type, MODEL)
        )
        return _response(200, parse_tool_input(anthropic_response))
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
