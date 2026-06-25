"""Localized text for the Circle APNs push notifications.

The recipient's language is resolved server-side (from their registered device,
see ``apns.user_lang``) so a friend's reaction / shared-meal / request / accept
push arrives in *their* app language instead of always-English. Strings mirror
the client's l10n keys (``circleSharedMeal`` / ``circleReactionNotif`` /
``circleRequestNotif`` / ``circleAcceptedNotif`` in app_en.arb / app_zh.arb) so
the background push reads identically to the in-app notification.

Backward-compatible: an unknown / absent lang falls back to English, exactly the
behavior before push localization existed.
"""

# key -> {lang -> template}. Only languages the app ships (en, zh) are listed;
# anything else falls back to "en".
_MESSAGES = {
    "shared_meal": {
        "en": "{name} shared a meal 🍵",
        "zh": "{name} 分享了一餐 🍵",
    },
    "reaction": {
        "en": "{name} reacted {emoji} to your meal",
        "zh": "{name} 对你的餐食回应了 {emoji}",
    },
    "invite": {
        "en": "{name} wants to join your circle 👋",
        "zh": "{name} 想加入你的圈子 👋",
    },
    "accept": {
        "en": "{name} accepted — you're connected 🎉",
        "zh": "{name} 接受了 — 你们已连接 🎉",
    },
}


def text(key, lang, **params):
    """The push string for ``key`` in ``lang`` (e.g. 'zh', 'zh-Hans', 'en-US'),
    formatted with ``params``. Falls back to English for any unknown language or
    key, and returns the raw template if a param is missing (never raises)."""
    table = _MESSAGES.get(key)
    if not table:
        return ""
    code = (lang or "en").replace("_", "-").split("-", 1)[0].lower()
    template = table.get(code) or table["en"]
    try:
        return template.format(**params)
    except (KeyError, IndexError, ValueError):
        return template
