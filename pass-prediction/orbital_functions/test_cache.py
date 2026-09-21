import unittest
from unittest.mock import MagicMock
import requests
from cache import validate, validate_json, refresh, SOURCES

# Structurally valid deterministic fixture with computed checksums.
def line(s):
    s = s.ljust(68)[:68]
    return s + str(sum(int(c) if c.isdigit() else c == '-' for c in s) % 10)
TLE = 'ISS\n' + line('1 25544U 98067A   26257.50000000  .00000000  00000-0  00000-0 0  999') + '\n' + line('2 25544  51.6400 120.0000 0001000  20.0000  30.0000 15.5000000012345') + '\n'
import json
JSON_DATA = json.dumps([{'OBJECT_NAME':'NEW SAT', 'OBJECT_ID':'2026-001A', 'NORAD_CAT_ID':100001,
'EPOCH':'2026-09-15T00:00:00.000000', 'ECCENTRICITY':0.001, 'INCLINATION':51.6,
'RA_OF_ASC_NODE':120, 'ARG_OF_PERICENTER':20, 'MEAN_ANOMALY':30, 'MEAN_MOTION':15.5,
'BSTAR':0.0001, 'EPHEMERIS_TYPE':0, 'ELEMENT_SET_NO':999, 'REV_AT_EPOCH':1, 'CLASSIFICATION_TYPE':'U'}])
class CacheTests(unittest.TestCase):
    def test_json_preserves_six_digit_id(self):
        self.assertEqual(json.loads(validate_json(JSON_DATA))[0]['NORAD_CAT_ID'], 100001)
        with self.assertRaises(ValueError): validate_json('[]')
        with self.assertRaises(ValueError): validate_json(JSON_DATA.replace('15.5', '-1'))
    def test_valid_crlf(self):
        self.assertEqual(validate(TLE.replace('\n','\r\n'), '25544'), TLE)
    def test_bad_payloads(self):
        for data in ('', '<html>error</html>', TLE[:-4], TLE.replace('51.6400','51.6500')):
            with self.assertRaises(ValueError): validate(data)
        with self.assertRaises(ValueError): validate(TLE, '48274')
    def test_failed_refresh_never_overwrites_cache(self):
        client, session = MagicMock(), MagicMock()
        session.get.side_effect = requests.Timeout('offline')
        with self.assertRaises(RuntimeError): refresh(client, session)
        client.bucket.assert_not_called()
        self.assertEqual(session.get.call_count, len(SOURCES))
    def test_invalid_success_response_never_overwrites_cache(self):
        client, session = MagicMock(), MagicMock()
        session.get.return_value.text = '<html>maintenance</html>'
        with self.assertRaises(RuntimeError): refresh(client, session)
        client.bucket.assert_not_called()
    def test_other_datasets_continue_after_one_failure(self):
        client, session = MagicMock(), MagicMock()
        def response_for(*args, **kwargs):
            response = MagicMock()
            response.text = TLE if kwargs['params']['FORMAT'] == 'TLE' else JSON_DATA
            return response
        session.get.side_effect = response_for
        with self.assertRaises(RuntimeError): refresh(client, session)
        self.assertEqual(client.bucket.return_value.blob.return_value.upload_from_string.call_count, 4)


class EndpointTests(unittest.TestCase):
    def setUp(self):
        from flask import Flask
        self.app = Flask(__name__)
    def call(self, query='', method='GET'):
        from flask import request
        from main import orbital_data
        with self.app.test_request_context('/?' + query, method=method):
            return orbital_data(request)
    def test_allowlist_and_method(self):
        self.assertEqual(self.call('category=../../private').status_code, 400)
        self.assertEqual(self.call('category=25544', 'POST').status_code, 405)
    def test_cached_response_and_staleness(self):
        from unittest.mock import patch
        from datetime import datetime, timezone, timedelta
        with patch('main.storage.Client') as factory:
            blob = factory.return_value.bucket.return_value.get_blob.return_value
            blob.download_as_text.return_value = TLE
            blob.updated = datetime.now(timezone.utc) - timedelta(hours=18)
            response = self.call('category=25544')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.headers['X-Orbital-Stale'], 'true')
            self.assertEqual(response.get_data(as_text=True), TLE)
            blob.updated -= timedelta(days=8)
            self.assertEqual(self.call('category=25544').status_code, 503)
    def test_missing_cache_is_retryable(self):
        from unittest.mock import patch
        with patch('main.storage.Client') as factory:
            factory.return_value.bucket.return_value.get_blob.return_value = None
            response = self.call('category=25544')
            self.assertEqual(response.status_code, 503)
            self.assertEqual(response.headers['Cache-Control'], 'no-store')


class ScheduledRefreshTests(unittest.TestCase):
    def test_fractional_scheduler_timestamp_reaches_refresh(self):
        from flask import Flask, request
        from unittest.mock import patch
        import main
        app = Flask(__name__)
        with app.test_request_context('/', method='POST', headers={
            'X-CloudScheduler-ScheduleTime': '2026-09-20T23:17:00.244034-07:00',
            'X-CloudScheduler-JobName': 'orbital-refresh-regression',
        }), patch.object(main, 'refresh') as refresh_cache:
            response = main.refresh_orbital_cache(request)
        self.assertEqual(response.status_code, 200)
        refresh_cache.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
