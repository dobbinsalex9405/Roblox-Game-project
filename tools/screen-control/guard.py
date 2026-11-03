"""Decides when the screen-control server must refuse to type.

Pure Python with no Windows imports, so CI can test it on Linux. The server
reads the focused field through UI Automation and passes what it found here
before every type_text and press_keys call. Anything uncertain is a refusal.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# Words that mark a field (its accessible name, automation id or class) as a
# password, one-time code, CAPTCHA or payment field.
FIELD_WORDS = (
    "password",
    "passwd",
    "passcode",
    "pin code",
    "2fa",
    "2-step",
    "two-step",
    "two-factor",
    "one-time",
    "otp",
    "verification",
    "security code",
    "enter code",
    "6-digit",
    "authenticator",
    "captcha",
    "recaptcha",
    "hcaptcha",
    "funcaptcha",
    "arkose",
    "card number",
    "cardnumber",
    "cc-number",
    "credit card",
    "debit card",
    "cvv",
    "cvc",
    "expiration",
    "expiry",
    "billing",
    "iban",
    "routing number",
    "account number",
)

# Words in the foreground window's title (in Chrome: the tab's title) that
# mark a whole page as sign-in, verification, CAPTCHA or payment.
PAGE_WORDS = (
    "sign in",
    "sign-in",
    "signin",
    "log in",
    "log-in",
    "login",
    "password",
    "2-step",
    "two-step",
    "two-factor",
    "verification",
    "verify your",
    "captcha",
    "checkout",
    "payment",
    "billing",
    "buy robux",
    "purchase",
)

# Text that is a secret whatever field it goes into.
SECRET_MARKERS = (
    "_|warning:-do-not-share-this",
    ".roblosecurity",
    "roblosecurity",
)


@dataclass
class Focus:
    """What UI Automation reported about the field that would get the keys."""

    window_title: str = ""
    name: str = ""
    automation_id: str = ""
    class_name: str = ""
    is_password: bool = False
    readable: bool = True
    # UI Automation framework ("Chrome" for Chrome and Edge pages, "Win32"...)
    # and control type name ("Edit", "Document", "Pane"...).
    framework: str = ""
    control_type: str = ""


def _match(text: str, words: tuple[str, ...]) -> str | None:
    # Split camelCase ids ("cardCvv" -> "card cvv"), then match short words
    # only as whole words so "otp" does not hit "footprint".
    low = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text).lower()
    for word in words:
        if len(word) <= 4:
            if re.search(rf"(?<![a-z0-9]){re.escape(word)}(?![a-z0-9])", low):
                return word
        elif word in low:
            return word
    return None


def page_refusal(*window_titles: str) -> str | None:
    """Return why a click must be refused, or None.

    Clicks are checked against the page, not the field: a click can confirm a
    purchase or answer a CAPTCHA without any typing.
    """
    for title in window_titles:
        word = _match(title, PAGE_WORDS)
        if word:
            return (
                f'the window looks like a sign-in, verification, CAPTCHA or payment '
                f'page ("{word}" in "{title}")'
            )
    return None


def refusal(focus: Focus, text: str = "") -> str | None:
    """Return why typing `text` (or pressing keys) must be refused, or None."""
    if not focus.readable:
        return (
            "could not read the focused field, so it cannot be confirmed "
            "that it is not a password, code, CAPTCHA or payment field"
        )
    if focus.is_password:
        return "the focused field is a password field"
    if focus.framework.lower() == "chrome" and focus.control_type in ("Document", "Pane", ""):
        # Chrome often keeps page contents hidden from UI Automation, so focus
        # reads as the whole page and a password field there would look like
        # nothing. Only typing into a field the browser exposes is allowed.
        return (
            "the browser does not expose which page field has focus, so it "
            "cannot be confirmed that it is not a password field (use the "
            "browser tools for typing in web pages)"
        )
    for value in (focus.name, focus.automation_id, focus.class_name):
        word = _match(value, FIELD_WORDS)
        if word:
            return f'the focused field looks sensitive ("{word}" in "{value}")'
    word = _match(focus.window_title, PAGE_WORDS)
    if word:
        return (
            f'the foreground window looks like a sign-in, verification or payment '
            f'page ("{word}" in "{focus.window_title}")'
        )
    word = _match(text, SECRET_MARKERS)
    if word:
        return "the text looks like a Roblox session cookie"
    return None
