"""Shared helpers for the Food at Peace Lambda handlers (vision proxy, auth,
sync).

Pure standard library plus a lazily-imported ``boto3`` (present in the Lambda
Python runtime; lazy so unit tests can stub secrets without importing it).
"""

import base64
import json

# SSM secrets are fetched once per cold start and cached here. Tests pre-populate
# this dict (via ``app._secrets`` / ``common._secrets`` — the same object) so no
# AWS call is ever made.
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
