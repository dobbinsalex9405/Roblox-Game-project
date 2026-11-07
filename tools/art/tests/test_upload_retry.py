"""upload.py's call() rides out a flaky network: 429/5xx answers and
connection-level failures (refused, reset, timed out) are retried a bounded
number of times, and anything else stops the upload at once."""
import io
import json
import os
import sys
import unittest
import urllib.error
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'blender'))
import upload  # noqa: E402

URL = 'https://apis.roblox.com/assets/v1/assets'


class Answer(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def ok():
    return Answer(json.dumps({'done': True}).encode())


def http(code):
    return urllib.error.HTTPError(URL, code, 'x', {}, io.BytesIO(b'{}'))


class CallRetry(unittest.TestCase):
    def run_call(self, effects, **kw):
        with mock.patch.object(upload.urllib.request, 'urlopen', side_effect=effects) as op, \
                mock.patch.object(upload.time, 'sleep') as sleep, \
                mock.patch('builtins.print'):
            try:
                return upload.call('POST', URL, 'k', b'', 'x', **kw), op.call_count, sleep.call_count
            except SystemExit as e:
                return e, op.call_count, sleep.call_count

    def test_connection_refused_is_retried(self):
        res, calls, sleeps = self.run_call([urllib.error.URLError(ConnectionRefusedError(111, 'refused')), ok()])
        self.assertEqual(res, {'done': True})
        self.assertEqual((calls, sleeps), (2, 1))

    def test_reset_and_timeout_are_retried(self):
        res, calls, _ = self.run_call([ConnectionResetError(), TimeoutError(), ok()])
        self.assertEqual(res, {'done': True})
        self.assertEqual(calls, 3)

    def test_server_errors_are_retried(self):
        res, calls, _ = self.run_call([http(429), http(503), http(504), ok()])
        self.assertEqual(res, {'done': True})
        self.assertEqual(calls, 4)

    def test_network_retries_are_bounded(self):
        res, calls, sleeps = self.run_call([urllib.error.URLError('down')] * 10)
        self.assertIsInstance(res, SystemExit)
        self.assertEqual((calls, sleeps), (upload.TRIES, upload.TRIES - 1))

    def test_client_errors_stop_at_once(self):
        res, calls, _ = self.run_call([http(400), ok()])
        self.assertIsInstance(res, SystemExit)
        self.assertEqual(calls, 1)
        with mock.patch.object(upload.urllib.request, 'urlopen', side_effect=[http(404)]), \
                mock.patch.object(upload.time, 'sleep'):
            with self.assertRaises(LookupError):
                upload.call('GET', URL, 'k', soft=True)


if __name__ == '__main__':
    unittest.main()
