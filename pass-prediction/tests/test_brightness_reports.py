import sys
from pathlib import Path
import unittest
from unittest.mock import Mock, patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'functions'))
from common.brightness_reports import validate, store, handle_report


class BrightnessTests(unittest.TestCase):
    def body(self):
        return {'id': '12345678-1234-1234-1234-123456789abc',
                'installationID': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                'fcmToken': 'synthetic-fcm-token-for-unit-test',
                'noradID': 25544, 'magnitude': 2.3, 'observedAt': 1800000000.0}

    def test_valid_report_preserves_satellite_brightness_and_private_token(self):
        _, reporter, value = validate(self.body(), 1800000001)
        self.assertEqual(value['norad_id'], 25544)
        self.assertEqual(value['magnitude'], 2.3)
        self.assertEqual(reporter, self.body()['installationID'])
        self.assertEqual(value['fcm_token'], self.body()['fcmToken'])

    def test_invalid_reports(self):
        for key, values in {'magnitude': [-.1, 5.1, True, float('nan'), float('inf'), '2'],
                            'observedAt': [0, 1800000400, True], 'noradID': [0, True, '25544'],
                            'installationID': ['bad'], 'fcmToken': ['', 'a b']}.items():
            for value in values:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    validate({**self.body(), key: value}, 1800000001)

    def test_idempotency_and_rate_limit(self):
        _, _, value = validate(self.body(), 1800000001)
        tx, report, limit = Mock(), Mock(), Mock()
        report.get.return_value.exists = False
        limit.get.return_value.to_dict.return_value = None
        store.to_wrap(tx, report, limit, value, 1800000001)
        self.assertEqual(tx.set.call_count, 2)
        tx.reset_mock()
        report.get.return_value.exists = True
        report.get.return_value.to_dict.return_value = value
        store.to_wrap(tx, report, limit, value, 1800000001)
        tx.set.assert_not_called()
        with self.assertRaises(ValueError):
            store.to_wrap(tx, report, limit, {**value, 'magnitude': 4}, 1800000001)
        report.get.return_value.exists = False
        limit.get.return_value.to_dict.return_value = {'window': 30000000, 'count': 10}
        with self.assertRaises(OverflowError):
            store.to_wrap(tx, report, limit, value, 1800000001)

    @patch('common.brightness_reports.app_check.verify_token', side_effect=ValueError())
    def test_unattested_request_never_writes(self, verify):
        request, db = Mock(), Mock()
        request.method, request.content_length = 'POST', 200
        self.assertEqual(handle_report(request, db)[1], 401)
        db.collection.assert_not_called()

    @patch('common.brightness_reports.store')
    @patch('common.brightness_reports.time.time', return_value=1800000001)
    @patch('common.brightness_reports.app_check.verify_token')
    def test_endpoint_success_and_failure(self, verify, clock, save):
        request, db = Mock(), Mock()
        request.method, request.content_length = 'POST', 200
        request.get_json.return_value = self.body()
        self.assertEqual(handle_report(request, db)[1], 204)
        save.side_effect = OverflowError()
        self.assertEqual(handle_report(request, db)[1], 429)
        save.side_effect = RuntimeError()
        self.assertEqual(handle_report(request, db)[1], 503)

if __name__ == '__main__': unittest.main()
