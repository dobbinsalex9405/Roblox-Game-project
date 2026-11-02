import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from guard import Focus, refusal  # noqa: E402


class GuardTest(unittest.TestCase):
    def test_plain_field_is_allowed(self):
        focus = Focus(window_title="Notepad", name="Text editor", class_name="RichEditD2DPT")
        self.assertIsNone(refusal(focus, "hello world"))

    def test_unreadable_focus_is_refused(self):
        self.assertIsNotNone(refusal(Focus(readable=False), "hi"))

    def test_password_flag_is_refused(self):
        self.assertIsNotNone(refusal(Focus(window_title="Notepad", is_password=True), "x"))

    def test_sensitive_field_names_are_refused(self):
        for name in ("Password", "Enter the 6-digit code", "Card number", "CVV", "Verification code"):
            with self.subTest(name=name):
                self.assertIsNotNone(refusal(Focus(window_title="Editor", name=name), "1"))

    def test_camel_case_ids_are_split(self):
        self.assertIsNotNone(refusal(Focus(window_title="Editor", automation_id="cardCvv"), "1"))
        self.assertIsNotNone(refusal(Focus(window_title="Editor", automation_id="newPassword"), "1"))

    def test_short_words_need_word_boundaries(self):
        focus = Focus(window_title="Editor", name="Footprint notes")
        self.assertIsNone(refusal(focus, "hi"))

    def test_sign_in_and_payment_pages_are_refused(self):
        for title in ("Log in to Roblox - Google Chrome", "Checkout - Google Chrome", "Buy Robux - Chrome"):
            with self.subTest(title=title):
                self.assertIsNotNone(refusal(Focus(window_title=title, name="Search"), "a"))

    def test_session_cookie_text_is_refused(self):
        focus = Focus(window_title="Notepad", name="Text editor")
        self.assertIsNotNone(refusal(focus, "_|WARNING:-DO-NOT-SHARE-THIS.--Sharing-this"))

    def test_file_dialog_is_allowed(self):
        focus = Focus(window_title="Open", name="File name:", class_name="Edit")
        self.assertIsNone(refusal(focus, r"C:\art\thumbnail-1.png"))


if __name__ == "__main__":
    unittest.main()
