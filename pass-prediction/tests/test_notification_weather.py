import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'functions'))
from common import notification_weather as weather
from common.notification_copy import COPY, notification_content
from common.description import LOCALIZATIONS


class WeatherTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 1, 22, 0, tzinfo=timezone.utc)
        self.start = self.now.replace(minute=58)
        self.end = self.start + timedelta(minutes=4)
        self.payload = {'schemaVersion': 1, 'weather': {'status': 'ok', 'stale': False,
            'fetchedAt': self.now.isoformat(), 'hours': [self.hour(self.now), self.hour(self.now + timedelta(hours=1))]}}
        self.transit = {'visible_above_10_deg_duration_sec': 240, 'visible_culmination_elev': 62.4,
            'elev10_rise': {'time': self.start.isoformat(), 'obs': {'azimuth': 315}},
            'culmination': {'time': self.end.isoformat()}}

    def hour(self, at, rain=False, chance=0, cloud=10):
        return {'time': at.isoformat(), 'conditionCode': 'Rain' if rain else 'PartlyCloudy',
                'precipitationChancePercent': chance, 'cloudCoverPercent': cloud}

    def classify(self):
        return weather.classify_weather(self.payload, self.start, self.end, self.now)

    def test_high_confidence_rain_requires_every_overlapping_hour(self):
        for hour in self.payload['weather']['hours']:
            hour.update(conditionCode='Rain', precipitationChancePercent=80)
        self.assertEqual(self.classify(), 'rain')
        self.payload['weather']['hours'][1]['precipitationChancePercent'] = 79.9
        self.assertEqual(self.classify(), 'possible_rain')
        self.payload['weather']['hours'][1].update(conditionCode='Clear', precipitationChancePercent=0)
        self.assertEqual(self.classify(), 'possible_rain')

    def test_probability_alone_never_suppresses(self):
        for hour in self.payload['weather']['hours']:
            hour['precipitationChancePercent'] = 100
        self.assertEqual(self.classify(), 'possible_rain')

    def test_snow_fog_and_other_visibility_conditions_keep_neutral_copy(self):
        for condition in weather.OTHER_VISIBILITY_CONDITIONS:
            with self.subTest(condition=condition):
                self.payload['weather']['hours'][0].update(conditionCode=condition, precipitationChancePercent=100)
                self.assertEqual(self.classify(), 'unknown')

    def test_cloud_and_possible_rain_boundaries_use_worst_overlap(self):
        for cover, expected in ((0, 'clear'), (29.9, 'clear'), (30, 'cloudy'), (69.9, 'cloudy'), (70, 'mostly_cloudy'), (100, 'mostly_cloudy')):
            self.payload['weather']['hours'][1]['cloudCoverPercent'] = cover
            self.assertEqual(self.classify(), expected)
        self.payload['weather']['hours'][0]['precipitationChancePercent'] = 30
        self.assertEqual(self.classify(), 'possible_rain')

    def test_stale_missing_malformed_and_future_data_never_suppress(self):
        baseline = copy.deepcopy(self.payload)
        for age in (900, 901, -1):
            self.payload['weather']['fetchedAt'] = (self.now - timedelta(seconds=age)).isoformat()
            self.assertEqual(self.classify(), 'unknown')
        for field, value in (('stale', True), ('stale', None), ('status', 'unavailable'), ('hours', []), ('hours', None), ('fetchedAt', 'invalid')):
            self.payload = copy.deepcopy(baseline)
            self.payload['weather'][field] = value
            self.assertEqual(self.classify(), 'unknown')
        self.payload = copy.deepcopy(baseline)
        self.payload['weather']['hours'].append(self.payload['weather']['hours'][0])
        self.assertEqual(self.classify(), 'unknown')
        for value in (None, -1, 101, True, float('nan'), '20'):
            self.payload = copy.deepcopy(baseline)
            self.payload['weather']['hours'][1]['cloudCoverPercent'] = value
            self.assertEqual(self.classify(), 'unknown')
        for payload in (None, [], {}, {'schemaVersion': 2}, {'schemaVersion': 1, 'weather': []}):
            self.assertEqual(weather.classify_weather(payload, self.start, self.end, self.now), 'unknown')

    def test_end_at_hour_boundary_does_not_require_next_hour(self):
        self.end = self.now + timedelta(hours=1)
        self.payload['weather']['hours'] = [self.hour(self.now, True, 100)]
        self.assertEqual(self.classify(), 'rain')

    def test_shadow_exit_and_visible_duration_define_lookup_window(self):
        shadow = self.now + timedelta(hours=1)
        self.transit['leaves_shadow'] = {'time': shadow.isoformat(), 'obs': {'azimuth': 270}}
        self.assertEqual(weather.visible_window(self.transit), (shadow, shadow + timedelta(minutes=4), 270, 62.4))
        self.transit['visible_above_10_deg_duration_sec'] = float('nan')
        self.assertIsNone(weather.visible_window(self.transit))

    def test_evening_weather_requested_for_afternoon_prominent_alert_with_oidc(self):
        self.start = self.now + timedelta(hours=6, minutes=21)
        self.transit['elev10_rise']['time'] = self.start.isoformat()
        response = MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(self.payload).encode()
        with patch.object(weather, 'WEATHER_URL', 'https://private-weather.example'), \
             patch.object(weather.id_token, 'fetch_id_token', return_value='test-identity') as identity, \
             patch.object(weather, 'urlopen', return_value=response) as fetch:
            weather.weather_for_pass(self.transit, {'lat': 37.77, 'lon': -122.42}, self.now)
        req = fetch.call_args.args[0]
        self.assertEqual(req.get_header('Authorization'), 'Bearer test-identity')
        self.assertEqual(identity.call_args.args[1], 'https://private-weather.example')
        query = parse_qs(urlparse(req.full_url).query)
        self.assertEqual(query['start'], [(self.now + timedelta(hours=6)).isoformat()])
        self.assertEqual(query['hours'], ['2'])
        self.assertEqual(fetch.call_args.kwargs['timeout'], 20)

    def test_network_and_auth_failure_and_past_window_fall_back(self):
        with patch.object(weather, 'WEATHER_URL', 'https://private-weather.example'), \
             patch.object(weather.id_token, 'fetch_id_token', side_effect=RuntimeError('unavailable')), \
             patch.object(weather, 'urlopen') as fetch:
            self.assertEqual(weather.weather_for_pass(self.transit, {'lat': 0, 'lon': 0}, self.now), 'unknown')
            fetch.assert_not_called()
        with patch.object(weather, 'WEATHER_URL', 'https://private-weather.example'), \
             patch.object(weather.id_token, 'fetch_id_token') as identity:
            self.assertEqual(weather.weather_for_pass(self.transit, {}, self.now + timedelta(hours=2)), 'unknown')
            identity.assert_not_called()

    def test_successful_wire_response_is_classified_and_transport_errors_are_neutral(self):
        response = MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(self.payload).encode()
        with patch.object(weather, 'WEATHER_URL', 'https://private-weather.example'), \
             patch.object(weather.id_token, 'fetch_id_token', return_value='test-identity'), \
             patch.object(weather, 'datetime', wraps=datetime) as clock, \
             patch.object(weather, 'urlopen', return_value=response) as fetch:
            clock.now.return_value = self.now
            observer = {'lat': 37.77, 'lon': -122.42}
            self.assertEqual(weather.weather_for_pass(self.transit, observer, self.now), 'clear')
            response.__enter__.return_value.read.return_value = b'x' * 65_537
            self.assertEqual(weather.weather_for_pass(self.transit, observer, self.now), 'unknown')
            fetch.side_effect = TimeoutError()
            self.assertEqual(weather.weather_for_pass(self.transit, observer, self.now), 'unknown')


class CompactCopyTests(unittest.TestCase):
    def setUp(self):
        self.transit = {'visible_above_10_deg_duration_sec': 240, 'visible_culmination_elev': 62.4,
            'elev10_rise': {'time': '2026-10-01T22:58:00Z', 'obs': {'azimuth': 315}}}

    def test_all_eight_locales_and_both_stations_have_complete_compact_copy(self):
        self.assertEqual(set(COPY), set(LOCALIZATIONS))
        for locale in COPY:
            for station in ('25544', '48274'):
                for state in ('clear', 'cloudy', 'mostly_cloudy', 'possible_rain', 'unknown'):
                    with self.subTest(locale=locale, station=station, state=state):
                        title, subtitle, body = notification_content(station, self.transit, -7 * 3600, locale, state)
                        self.assertIn('15:58', title)
                        self.assertIn('62°', subtitle)
                        self.assertNotIn('15:58', body)
                        self.assertNotIn('{', title + subtitle + body)
                        self.assertTrue(all('\n' not in s for s in (title, subtitle, body)))
                        self.assertLessEqual(len(subtitle), 55)
                        self.assertLessEqual(len(body), 65)
                        self.assertEqual(body, COPY[locale][state])

    def test_english_example_and_seconds_and_shadow_exit(self):
        self.assertEqual(notification_content('25544', self.transit, -7 * 3600, weather='cloudy'),
                         ('ISS · 15:58', 'Look NW · 4 min · Up to 62°', 'Clouds may obscure the view.'))
        self.transit['visible_above_10_deg_duration_sec'] = 30
        self.transit['leaves_shadow'] = {'time': '2026-10-01T23:00:00Z', 'obs': {'azimuth': 270}}
        title, subtitle, _ = notification_content('25544', self.transit, -7 * 3600)
        self.assertEqual(title, 'ISS · 16:00')
        self.assertEqual(subtitle, 'Look W · 30 sec · Up to 62°')

    def test_locale_aliases_and_malformed_pass_keep_neutral_copy(self):
        for alias, locale in (('zh-Hans-CN', 'zh_Hans'), ('pt-BR', 'pt'), ('fr-CA', 'fr'), ('unknown', 'en')):
            self.assertEqual(notification_content('25544', self.transit, 0, alias), notification_content('25544', self.transit, 0, locale))
        self.assertEqual(notification_content('25544', {}, 0),
                         ('ISS', 'Viewing details are unavailable for this pass.', 'Check the sky before heading out.'))


if __name__ == '__main__':
    unittest.main()
