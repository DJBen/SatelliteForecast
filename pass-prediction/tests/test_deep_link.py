import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('deep_link', Path(__file__).resolve().parents[1] / 'functions/common/deep_link.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class DeepLinkPayloadTests(unittest.TestCase):
    def test_utc_naive_and_offset_times_match(self):
        for value in ('2026-09-18T07:00:00', '2026-09-18T07:00:00Z', '2026-09-18T09:00:00+02:00'):
            self.assertEqual(module.pass_time_data({'culmination': {'time': value}}), {'passTime': '1789714800.0'})

    def test_missing_and_invalid_times_preserve_legacy_route(self):
        for value in (None, '', 'bad', 123, '1900-01-01T00:00:00Z'):
            self.assertEqual(module.pass_time_data({'culmination': {'time': value}}), {})
        self.assertEqual(module.pass_time_data(None), {})
