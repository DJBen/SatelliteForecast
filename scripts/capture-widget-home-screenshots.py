#!/usr/bin/env python3
"""Capture the Home Screen widget slot (06-widgets) in each store locale.

The simulator's system language, region and simulated location are switched per locale, the
simulator is rebooted so SpringBoard and the widget extension pick up the language, the app is
launched to refresh the shared widget forecast for that observer, and the first Home Screen
page (prepared beforehand with the medium and large Space Station widgets) is captured at
9:41 with a full battery. The widget data is the live forecast for the locale's observer at
capture time, not the reviewed historical pass moments used by the in-app slots.
"""
import argparse
import os
import json
import struct
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = {
    'en-US': ('en-US', 'en_US', 37.486743, -122.226560, 'America/Los_Angeles'),
    'fr-FR': ('fr-FR', 'fr_FR', 45.764, 4.8357, 'Europe/Paris'),
    'es-ES': ('es-ES', 'es_ES', 40.4168, -3.7038, 'Europe/Madrid'),
    'pt-BR': ('pt-BR', 'pt_BR', -23.5505, -46.6333, 'America/Sao_Paulo'),
    'ru': ('ru-RU', 'ru_RU', 48.708, 44.5133, 'Europe/Volgograd'),
    'ja': ('ja-JP', 'ja_JP', 35.6762, 139.6503, 'Asia/Tokyo'),
    'ko': ('ko-KR', 'ko_KR', 37.5665, 126.978, 'Asia/Seoul'),
    'zh-Hans': ('zh-Hans-CN', 'zh_CN', 31.2304, 121.4737, 'Asia/Shanghai'),
}
BUNDLE = 'io.djben.SatelliteForecast'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--locales', nargs='+', choices=LOCALES, default=list(LOCALES))
parser.add_argument('--simulator', default='0D39CA43-2212-46F4-AE51-A38A3DDDB9BC')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--settle', type=float, default=35, help='seconds to let the app refresh and widgets reload')
parser.add_argument('--restore-language', default='en-US')
args = parser.parse_args()
args.output = args.output.resolve()


def simctl(*a, check=True, capture=False):
    return subprocess.run(['xcrun', 'simctl', *a], check=check, capture_output=capture, text=True)


def set_language(language, region_locale, tz):
    simctl('spawn', args.simulator, 'defaults', 'write', '.GlobalPreferences', 'AppleLanguages', '-array', language)
    simctl('spawn', args.simulator, 'defaults', 'write', '.GlobalPreferences', 'AppleLocale', '-string', region_locale)


def reboot(tz):
    # launchd_sim inherits TZ from the boot command's environment; every process on the device
    # (SpringBoard, the widget host, the app) then formats times in that zone.
    simctl('shutdown', args.simulator, check=False)
    time.sleep(3)
    subprocess.run(['xcrun', 'simctl', 'boot', args.simulator], check=True, env={**os.environ, 'TZ': tz, 'SIMCTL_CHILD_TZ': tz})
    simctl('bootstatus', args.simulator, '-b')
    time.sleep(10)


try:
    for locale in args.locales:
        language, region_locale, lat, lon, tz = LOCALES[locale]
        folder = args.output / locale
        folder.mkdir(parents=True, exist_ok=True)
        simctl('boot', args.simulator, check=False)
        set_language(language, region_locale, tz)
        reboot(tz)
        simctl('ui', args.simulator, 'appearance', 'dark')
        simctl('location', args.simulator, 'set', f'{lat},{lon}')
        refresh_started = time.time()
        simctl('launch', args.simulator, BUNDLE)
        time.sleep(args.settle)
        # The first forecast can take longer while all sky charts are generated.
        # Never publish a setup placeholder just because a fixed delay elapsed.
        groups = simctl('get_app_container', args.simulator, BUNDLE, 'groups', capture=True).stdout
        group_path = next(line.split('\t', 1)[1] for line in groups.splitlines()
                          if line.startswith('group.io.djben.SatelliteForecast\t'))
        forecast_file = Path(group_path) / 'widget-forecast-v1.json'
        deadline = time.time() + 180
        while True:
            try:
                forecast = json.loads(forecast_file.read_text())
                ready = forecast_file.stat().st_mtime >= refresh_started and bool(forecast.get('passes'))
            except (OSError, ValueError):
                ready = False
            if ready:
                break
            if time.time() >= deadline:
                raise RuntimeError(f'{locale}: widget forecast was not ready; no screenshot captured')
            time.sleep(3)
        # Let WidgetKit finish archiving the refreshed timeline before restarting its host.
        time.sleep(30)
        # Terminating the app would land SpringBoard on the page holding its icon, and restarting
        # SpringBoard alone leaves the status bar blank for a while. A clean reboot shows the first
        # page, where the widgets live, with the widget forecast already written.
        reboot(tz)
        simctl('ui', args.simulator, 'appearance', 'dark')
        time.sleep(45)
        simctl('status_bar', args.simulator, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active',
               '--wifiBars', '3', '--cellularMode', 'active', '--cellularBars', '4', '--batteryState', 'discharging', '--batteryLevel', '100')
        time.sleep(6)
        path = folder / '06-widgets.png'
        simctl('io', args.simulator, 'screenshot', str(path), capture=True)
        png = path.read_bytes()
        if png[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', png[16:24]) != (1320, 2868):
            raise RuntimeError(f'{path}: wrong image dimensions')
        print(f'{locale}: captured 06-widgets', flush=True)
finally:
    simctl('status_bar', args.simulator, 'clear', check=False)
    language, region_locale, lat, lon, tz = LOCALES[args.restore_language]
    set_language(language, region_locale, tz)
