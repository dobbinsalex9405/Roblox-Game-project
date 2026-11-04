import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from guard import Focus, covered_refusal, element_refusal, page_refusal, refusal  # noqa: E402


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

    def test_captcha_field_is_refused(self):
        self.assertIsNotNone(refusal(Focus(window_title="Editor", name="Enter the CAPTCHA"), "a"))

    def test_payment_page_is_refused(self):
        self.assertIsNotNone(refusal(Focus(window_title="Payment - Google Chrome", name="Search"), "a"))

    def test_clicks_on_checkout_pages_are_refused(self):
        for title in ("Checkout - Google Chrome", "Buy Robux - Chrome", "Verify you are human - captcha"):
            with self.subTest(title=title):
                self.assertIsNotNone(page_refusal(title))

    def test_clicks_check_every_window_given(self):
        self.assertIsNotNone(page_refusal("Notepad", "Log in to Roblox - Google Chrome"))

    def test_clicks_elsewhere_are_allowed(self):
        self.assertIsNone(page_refusal("Notepad", "Roblox Creator Hub - Google Chrome"))

    def test_opaque_browser_page_is_refused(self):
        for control_type in ("Document", "Pane", ""):
            with self.subTest(control_type=control_type):
                focus = Focus(window_title="Creator Hub - Google Chrome", framework="Chrome", control_type=control_type)
                self.assertIsNotNone(refusal(focus, "a"))

    def test_exposed_browser_field_is_allowed(self):
        focus = Focus(
            window_title="Creator Hub - Google Chrome", name="Address and search bar", framework="Chrome", control_type="Edit"
        )
        self.assertIsNone(refusal(focus, "https://create.roblox.com"))

    def test_purchase_elements_are_refused(self):
        for name in ("Buy Robux", "Purchase", "Checkout", "Log In", "Payment method"):
            with self.subTest(name=name):
                self.assertIsNotNone(element_refusal(name))

    def test_plain_elements_are_allowed(self):
        for name in ("Upload thumbnail", "Open", "Add New Tab"):
            with self.subTest(name=name):
                self.assertIsNone(element_refusal(name))

    def test_covered_element_is_not_clicked(self):
        # The Claude app (111, no owner) covers Notepad (222).
        self.assertIsNotNone(covered_refusal([111], 222, "Claude"))

    def test_uncovered_element_is_clicked(self):
        self.assertIsNone(covered_refusal([222], 222, "Notepad"))

    def test_menu_owned_by_target_is_clicked(self):
        # A dropdown (333) is its own top-level window, owned by Notepad (222).
        self.assertIsNone(covered_refusal([333, 222], 222, ""))

    def test_dialog_as_target_is_clicked(self):
        # The "Open" dialog (444) is the target; it is owned by Chrome (555).
        self.assertIsNone(covered_refusal([444, 555], 444, "Open"))

    def test_dialog_over_other_target_is_not_clicked(self):
        # An "Open" dialog owned by Chrome covers Notepad.
        self.assertIsNotNone(covered_refusal([444, 555], 222, "Open"))

    def test_file_dialog_is_allowed(self):
        focus = Focus(window_title="Open", name="File name:", class_name="Edit")
        self.assertIsNone(refusal(focus, r"C:\art\thumbnail-1.png"))


if __name__ == "__main__":
    unittest.main()
