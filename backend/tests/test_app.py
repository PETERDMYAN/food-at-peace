import json

import pytest

import app

TOKEN = "secret-token"


@pytest.fixture(autouse=True)
def stub_secrets():
    """Pre-populate the secret cache so no AWS/SSM call is ever made."""
    app._secrets.clear()
    app._secrets[app.ANTHROPIC_KEY_PARAM] = "sk-ant-test"
    app._secrets[app.APP_TOKEN_PARAM] = TOKEN
    yield
    app._secrets.clear()


def _event(body, token=TOKEN):
    headers = {"content-type": "application/json"}
    if token is not None:
        headers["x-app-token"] = token
    return {"headers": headers, "body": json.dumps(body), "isBase64Encoded": False}


def _anthropic_tool_response(**input_overrides):
    food = {
        "name": "Toast",
        "calories": 120,
        "proteinG": 4,
        "satFatG": 1,
        "portionDescription": "1 slice",
        "confidence": "high",
    }
    food.update(input_overrides)
    return {
        "stop_reason": "tool_use",
        "content": [{"type": "tool_use", "name": "log_food", "input": food}],
    }


# --- Pure helpers ------------------------------------------------------------


def test_build_request_body_targets_model_and_forces_tool():
    body = app.build_request_body("AAAA", "image/jpeg", "claude-sonnet-4-6")
    assert body["model"] == "claude-sonnet-4-6"
    assert body["tool_choice"]["name"] == "log_food"
    assert body["tools"][0]["name"] == "log_food"


def test_build_request_body_carries_image_and_cached_system_prompt():
    body = app.build_request_body("AAAA", "image/png", "claude-sonnet-4-6")
    image = next(b for b in body["messages"][0]["content"] if b["type"] == "image")
    assert image["source"]["media_type"] == "image/png"
    assert image["source"]["data"] == "AAAA"
    assert body["system"][0]["cache_control"] == {"type": "ephemeral"}


def test_language_directive_defaults_to_english():
    assert app.language_directive(None) == ""
    assert app.language_directive("en") == ""
    assert app.language_directive("fr") == ""


def test_language_directive_zh_variants_request_chinese():
    for code in ("zh", "zh-Hans", "zh_CN", "ZH"):
        assert "Simplified Chinese" in app.language_directive(code)


def test_build_request_body_localizes_user_prompt_only_when_lang_set():
    def user_text(body):
        blocks = body["messages"][0]["content"]
        return next(b for b in blocks if b["type"] == "text")["text"]

    en = app.build_request_body("A", "image/jpeg", "m")
    zh = app.build_request_body("A", "image/jpeg", "m", lang="zh")
    assert "Simplified Chinese" not in user_text(en)
    assert "Simplified Chinese" in user_text(zh)
    # The cache_control'd system prefix is identical regardless of language.
    assert en["system"] == zh["system"]


def test_parse_tool_input_reads_log_food():
    out = app.parse_tool_input(_anthropic_tool_response(name="Chicken salad"))
    assert out["name"] == "Chicken salad"
    assert out["calories"] == 120


def test_parse_tool_input_raises_without_tool_use():
    with pytest.raises(app.ProxyError) as exc:
        app.parse_tool_input({"stop_reason": "end_turn", "content": [{"type": "text"}]})
    assert exc.value.status == 502


def test_map_anthropic_error_413_and_429_are_user_actionable():
    assert app._map_anthropic_error(413, "").status == 413
    assert app._map_anthropic_error(429, "").status == 429


def test_map_anthropic_error_hides_server_key_problems_as_502():
    # A bad/credit-less *server* key must not tell the user to check Settings.
    assert app._map_anthropic_error(401, "").status == 502
    assert app._map_anthropic_error(403, "").status == 502
    assert app._map_anthropic_error(500, "").status == 502


# --- Handler -----------------------------------------------------------------


def test_handler_rejects_bad_token():
    resp = handler_with({"image": "AAAA", "mediaType": "image/jpeg"}, token="nope")
    assert resp["statusCode"] == 401


def test_handler_rejects_missing_token():
    resp = handler_with({"image": "AAAA", "mediaType": "image/jpeg"}, token=None)
    assert resp["statusCode"] == 401


def test_handler_rejects_missing_image(monkeypatch):
    _stub_anthropic(monkeypatch)
    resp = app.handler(_event({"mediaType": "image/jpeg"}), None)
    assert resp["statusCode"] == 400


def test_handler_happy_path(monkeypatch):
    captured = _stub_anthropic(monkeypatch)
    resp = app.handler(_event({"image": "AAAA", "mediaType": "image/jpeg"}), None)
    assert resp["statusCode"] == 200
    out = json.loads(resp["body"])
    assert out["name"] == "Toast"
    assert out["calories"] == 120
    # The Anthropic call received the configured key + built body.
    assert captured["api_key"] == "sk-ant-test"
    assert captured["body"]["tool_choice"]["name"] == "log_food"


def test_handler_forwards_lang_to_the_prompt(monkeypatch):
    captured = _stub_anthropic(monkeypatch)
    resp = app.handler(
        _event({"image": "AAAA", "mediaType": "image/jpeg", "lang": "zh"}), None
    )
    assert resp["statusCode"] == 200
    blocks = captured["body"]["messages"][0]["content"]
    text = next(b for b in blocks if b["type"] == "text")["text"]
    assert "Simplified Chinese" in text


def test_handler_surfaces_anthropic_error(monkeypatch):
    def boom(api_key, body):
        raise app.ProxyError(413, "That image is too large. Try another photo.")

    monkeypatch.setattr(app, "_call_anthropic", boom)
    resp = app.handler(_event({"image": "AAAA", "mediaType": "image/jpeg"}), None)
    assert resp["statusCode"] == 413
    assert "too large" in json.loads(resp["body"])["error"]["message"]


# --- helpers -----------------------------------------------------------------


def _stub_anthropic(monkeypatch):
    """Replace the network call with a canned tool response; return a dict that
    records what the handler passed in."""
    captured = {}

    def fake_call(api_key, body):
        captured["api_key"] = api_key
        captured["body"] = body
        return _anthropic_tool_response()

    monkeypatch.setattr(app, "_call_anthropic", fake_call)
    return captured


def handler_with(body, token):
    return app.handler(_event(body, token=token), None)
