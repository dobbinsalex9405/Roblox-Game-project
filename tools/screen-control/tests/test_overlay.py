import sys
import threading
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import overlay  # noqa: E402


class OverlayTest(unittest.TestCase):
    def setUp(self):
        overlay._started = True  # never start the Tk thread in tests
        overlay._stopped_at = None
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

    def test_action_after_timed_out_task_shows_it_briefly(self):
        overlay.begin()
        overlay._last -= overlay.SESSION_TIMEOUT + 1  # the task went quiet
        overlay.touch()
        now = overlay._last
        self.assertFalse(overlay.visible(now + overlay.IDLE_SECONDS + 1))

    def test_begin_after_timed_out_task_starts_a_new_one(self):
        overlay.begin()
        overlay._last -= overlay.SESSION_TIMEOUT + 1
        overlay.begin()
        now = overlay._last
        self.assertTrue(overlay.visible(now + 120))


class PromptTest(unittest.TestCase):
    """The centred prompt on the first use of the screen in a task."""

    def setUp(self):
        overlay._started = True  # never start the Tk thread in tests
        overlay._stopped_at = None
        overlay.end()
        self.asked = []
        self.answer = overlay.ASKED
        self.real_ask = overlay._ask
        overlay._ask = lambda task, action: self.asked.append((task, action)) or self.answer

    def tearDown(self):
        overlay._ask = self.real_ask

    def test_first_use_asks_then_stays_quiet(self):
        self.assertEqual(overlay.start("Upload thumbnails", "begin_control"), overlay.ASKED)
        overlay.begin()
        self.assertEqual(overlay.start("", "click"), overlay.QUIET)
        self.assertEqual(overlay.start("", "type_text"), overlay.QUIET)
        self.assertEqual(self.asked, [("Upload thumbnails", "begin_control")])

    def test_first_use_without_begin_control_asks_too(self):
        self.assertEqual(overlay.start("", "screenshot"), overlay.ASKED)
        self.assertEqual(overlay.start("", "click"), overlay.QUIET)
        self.assertEqual(self.asked, [("", "screenshot")])

    def test_server_start_does_not_count_as_a_use(self):
        overlay.touch()  # the server logs at startup, which touches
        self.assertEqual(overlay.start("", "screenshot"), overlay.ASKED)

    def test_prompt_shows_the_border(self):
        overlay._ask = lambda task, action: (self.asked.append(overlay.visible(time.monotonic())), overlay.ASKED)[1]
        overlay.start("t", "begin_control")
        self.assertEqual(self.asked, [True])

    def test_end_control_means_the_next_use_asks_again(self):
        overlay.start("first task", "begin_control")
        overlay.begin()
        overlay.end()
        self.assertEqual(overlay.start("next turn", "begin_control"), overlay.ASKED)
        self.assertEqual(len(self.asked), 2)

    def test_quiet_for_session_timeout_asks_again(self):
        overlay.start("t", "begin_control")
        overlay.begin()
        overlay._last -= overlay.SESSION_TIMEOUT + 1  # the task went quiet
        self.assertEqual(overlay.start("", "click"), overlay.ASKED)
        self.assertEqual(len(self.asked), 2)

    def test_a_different_session_is_asked_for(self):
        a, b = object(), object()
        self.assertEqual(overlay.start("a's task", "begin_control", a), overlay.ASKED)
        self.assertEqual(overlay.start("", "click", a), overlay.QUIET)
        self.assertEqual(overlay.start("b's task", "begin_control", b), overlay.ASKED)
        self.assertEqual(overlay.start("", "click", b), overlay.QUIET)
        self.assertEqual(overlay.start("", "click", a), overlay.ASKED)  # a is back
        self.assertEqual(len(self.asked), 3)

    def test_stop_refuses_this_and_later_calls(self):
        self.answer = overlay.STOPPED
        self.assertEqual(overlay.start("t", "begin_control"), overlay.STOPPED)
        self.assertFalse(overlay.visible(time.monotonic()))  # border off at once
        self.answer = overlay.ASKED
        self.assertEqual(overlay.start("again", "begin_control"), overlay.STOPPED)
        self.assertEqual(overlay.start("", "click", object()), overlay.STOPPED)
        self.assertEqual(len(self.asked), 1)  # refused without asking again

    def test_stop_wears_off(self):
        self.answer = overlay.STOPPED
        overlay.start("t", "begin_control")
        overlay._stopped_at -= overlay.STOP_SECONDS + 1
        self.answer = overlay.ASKED
        self.assertEqual(overlay.start("later", "begin_control"), overlay.ASKED)

    def test_prompt_that_cannot_show_goes_ahead_once(self):
        self.answer = overlay.UNSHOWN
        self.assertEqual(overlay.start("t", "begin_control"), overlay.UNSHOWN)
        self.assertEqual(overlay.start("", "click"), overlay.QUIET)


class AskTest(unittest.TestCase):
    """_ask hands the prompt to the Tk thread and waits for its answer."""

    def setUp(self):
        overlay._pending = None
        self.wait = overlay.PROMPT_SECONDS
        overlay.PROMPT_SECONDS = -2.5  # wait 0.5 s in tests

    def tearDown(self):
        overlay.PROMPT_SECONDS = self.wait
        overlay._pending = None

    def test_answer_from_the_prompt(self):
        def tk_thread():
            while (request := overlay._take_pending()) is None:
                time.sleep(0.005)
            request["answer"] = overlay.STOPPED
            request["done"].set()

        threading.Thread(target=tk_thread).start()
        self.assertEqual(overlay._ask("t", "click"), overlay.STOPPED)

    def test_no_tk_thread_goes_ahead_and_withdraws_the_request(self):
        self.assertEqual(overlay._ask("t", "click"), overlay.UNSHOWN)
        self.assertIsNone(overlay._take_pending())


class PromptTextTest(unittest.TestCase):
    def test_task_is_shown(self):
        heading, detail, count = overlay.prompt_lines("Upload  the\nthumbnails", "begin_control", 4)
        self.assertEqual(heading, "Claude is about to use your screen")
        self.assertEqual(detail, "Task: Upload the thumbnails")
        self.assertIn("Starting in 4 s", count)
        self.assertIn("Stop", count)
        self.assertIn("10 minutes", count)

    def test_no_task_names_the_first_action(self):
        self.assertEqual(overlay.prompt_lines("", "click", 3)[1], "No task given. First action: click")

    def test_long_task_is_cut(self):
        detail = overlay.prompt_lines("x" * 500, "", 1)[1]
        self.assertLessEqual(len(detail), len("Task: ") + 120)
        self.assertTrue(detail.endswith("\u2026"))


if __name__ == "__main__":
    unittest.main()
