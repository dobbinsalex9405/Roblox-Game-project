import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import overlay  # noqa: E402


class OverlayTest(unittest.TestCase):
    def setUp(self):
        overlay._started = True  # never start the Tk thread in tests
        overlay.end()

    def test_action_shows_it_briefly(self):
        overlay.touch()
        now = overlay._last
        self.assertTrue(overlay.visible(now + 1))
        self.assertFalse(overlay.visible(now + overlay.IDLE_SECONDS + 1))

    def test_task_keeps_it_on_between_actions(self):
        overlay.begin()
        now = overlay._last
        self.assertTrue(overlay.visible(now + 120))

    def test_end_turns_it_off_at_once(self):
        overlay.begin()
        now = overlay._last
        overlay.end()
        self.assertFalse(overlay.visible(now + 0.1))

    def test_abandoned_task_times_out(self):
        overlay.begin()
        now = overlay._last
        self.assertFalse(overlay.visible(now + overlay.SESSION_TIMEOUT + 1))


if __name__ == "__main__":
    unittest.main()
