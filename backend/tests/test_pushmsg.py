import pushmsg


def test_english_default():
    assert pushmsg.text("reaction", "en", name="Eva", emoji="❤️") == (
        "Eva reacted ❤️ to your meal"
    )


def test_chinese_localized():
    assert pushmsg.text("reaction", "zh", name="Eva", emoji="❤️") == (
        "Eva 对你的餐食回应了 ❤️"
    )
    assert pushmsg.text("shared_meal", "zh", name="Eva") == "Eva 分享了一餐 🍵"


def test_region_suffix_normalizes_to_base_language():
    assert pushmsg.text("shared_meal", "zh-Hans", name="Eva") == "Eva 分享了一餐 🍵"
    assert pushmsg.text("shared_meal", "en_US", name="Eva") == "Eva shared a meal 🍵"


def test_unknown_language_falls_back_to_english():
    assert pushmsg.text("invite", "fr", name="Eva") == "Eva wants to join your circle 👋"
    assert pushmsg.text("accept", None, name="Eva") == "Eva accepted — you're connected 🎉"


def test_unknown_key_is_empty_not_an_error():
    assert pushmsg.text("nope", "en", name="Eva") == ""


def test_missing_param_does_not_raise():
    # No emoji supplied → returns the template rather than throwing.
    out = pushmsg.text("reaction", "en", name="Eva")
    assert "Eva" not in out or "{" in out  # template returned, no KeyError
