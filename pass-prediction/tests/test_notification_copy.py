import copy
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'functions/common/description.py'
spec = importlib.util.spec_from_file_location('notification_description', MODULE)
description = importlib.util.module_from_spec(spec)
spec.loader.exec_module(description)


class NotificationCopyTests(unittest.TestCase):
    def setUp(self):
        self.transit = {
            'visible_above_10_deg_duration_sec': 240,
            'visible_culmination_elev': 62.4,
            'elev10_rise': {'time': '2026-09-18T03:38:00Z', 'obs': {'azimuth': 315}},
            'culmination': {'time': '2026-09-18T03:42:00Z', 'obs': {'azimuth': 180}},
        }

    def test_regular_title_matches_scheduler_not_rise(self):
        self.assertEqual(description.get_localized_satellite_title('25544', is_rising=True),
                         'ISS passes by soon')
        self.assertEqual(description.get_localized_satellite_title('48274'),
                         'A chance to spot Tiangong')

    def test_local_time_direction_and_rounded_elevation(self):
        self.assertEqual(description.describe_transit(self.transit, -7 * 3600),
                         'Look northwest around 20:38. It reaches 62° above the horizon, '
                         'with about 4 min to watch if skies are clear.')

    def test_shadow_exit_changes_viewing_time_and_direction(self):
        self.transit['leaves_shadow'] = {
            'time': '2026-09-18T03:40:00Z', 'obs': {'azimuth': 270}}
        body = description.describe_transit(self.transit, -7 * 3600)
        self.assertIn('Look west around 20:40.', body)
        self.transit['leaves_shadow']['time'] = '2026-09-18T03:30:00Z'
        self.assertIn('Look northwest around 20:38.',
                      description.describe_transit(self.transit, -7 * 3600))

    def test_low_long_and_morning_passes_are_not_overhead_or_tonight(self):
        self.transit['visible_culmination_elev'] = 20
        self.transit['visible_above_10_deg_duration_sec'] = 360
        self.transit['elev10_rise']['time'] = '2026-09-18T06:00:00Z'
        body = description.describe_prominent_transit('25544', self.transit, 0)
        self.assertIn('06:00', body)
        self.assertIn('20°', body)
        self.assertNotIn('tonight', body.lower())
        self.assertNotIn('overhead', body.lower())
        self.transit['visible_above_10_deg_duration_sec'] = 30
        self.assertIn('30 sec', description.describe_prominent_transit('25544', self.transit, 0))

    def test_all_locales_render_both_satellites_and_notification_types(self):
        for locale in description.LOCALIZATIONS:
            for sat_id in ('25544', '48274'):
                for regular in (True, False):
                    with self.subTest(locale=locale, sat_id=sat_id, regular=regular):
                        title = description.get_localized_satellite_title(sat_id, locale, regular)
                        body = description.describe_prominent_transit(sat_id, self.transit, 0, locale)
                        self.assertNotIn('{', title + body)
                        self.assertIn('03:38', body)
                        self.assertIn('62°', body)
                        self.assertEqual(body, description.describe_transit(self.transit, 0, locale))

    def test_locale_aliases_and_unsupported_locale_fallback(self):
        for locale in ('zh-Hans-CN', 'zh_Hans', 'zh-CN'):
            self.assertEqual(description._get_locale_code(locale), 'zh_Hans')
        self.assertEqual(description._get_locale_code('pt-BR'), 'pt')
        self.assertEqual(description._get_locale_code('zh-Hant'), 'en')
        self.assertEqual(description._get_locale_code('unknown'), 'en')

    def test_time_formats_and_midnight_rollover(self):
        for value in ('2026-09-18T03:38:00', '2026-09-18T03:38:00Z',
                      '2026-09-18T05:38:00+02:00'):
            self.transit['elev10_rise']['time'] = value
            self.assertIn('20:38', description.describe_transit(self.transit, -7 * 3600))

    def test_missing_and_invalid_data_produce_readable_fallbacks(self):
        self.assertEqual(description.describe_transit({}, 0), 'No visible pass is expected.')
        for field in ('elev10_rise', 'visible_culmination_elev'):
            transit = copy.deepcopy(self.transit)
            del transit[field]
            self.assertEqual(description.describe_transit(transit, 0),
                             'Viewing details are unavailable for this pass.')
        for invalid in (-1, float('nan'), float('inf')):
            self.transit['visible_culmination_elev'] = invalid
            self.assertEqual(description.describe_transit(self.transit, 0),
                             'Viewing details are unavailable for this pass.')


if __name__ == '__main__':
    unittest.main()
