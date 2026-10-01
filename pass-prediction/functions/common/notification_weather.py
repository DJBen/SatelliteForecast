"""Fresh pass-window weather, obtained with runtime identity and shared H3 caching."""
from datetime import datetime, timedelta, timezone
import json
import math
import os
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from google.auth.transport.requests import Request as AuthRequest
from google.oauth2 import id_token

# Filled with the deployed private Cloud Run URI; audience must match it exactly.
WEATHER_URL = os.environ.get('NOTIFICATION_WEATHER_URL', 'https://notificationweather-eru2bds77q-uw.a.run.app')
RAIN_CONDITIONS = {'Rain', 'HeavyRain', 'Drizzle', 'SunShowers', 'FreezingRain',
                   'FreezingDrizzle', 'Thunderstorms', 'StrongStorms', 'ScatteredThunderstorms'}
OTHER_VISIBILITY_CONDITIONS = {'Snow', 'HeavySnow', 'BlowingSnow', 'Flurries', 'SunFlurries',
    'Blizzard', 'Sleet', 'WintryMix', 'Foggy', 'Haze', 'Smoky', 'BlowingDust', 'Hurricane', 'TropicalStorm'}


def utc(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return (parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed).astimezone(timezone.utc)


def visible_window(transit):
    """Illuminated window above 10°, shared by notification timing and weather."""
    try:
        duration = float(transit['visible_above_10_deg_duration_sec'])
        elevation = float(transit['visible_culmination_elev'])
        start = transit['elev10_rise']
        start_time = utc(start['time'])
        shadow = transit.get('leaves_shadow')
        if shadow and utc(shadow['time']) > start_time:
            start, start_time = shadow, utc(shadow['time'])
        azimuth = float(start['obs']['azimuth'])
        if not all(math.isfinite(v) for v in (duration, elevation, azimuth)) or not 0 < duration <= 3600 or not 0 <= elevation <= 90:
            return None
        return start_time, start_time + timedelta(seconds=duration), azimuth, elevation
    except (KeyError, TypeError, ValueError, AttributeError, OverflowError):
        return None


def percent(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and 0 <= value <= 100 else None


def classify_weather(payload, start, end, now):
    """Only fresh, complete hourly coverage can suppress an automatic reminder."""
    try:
        if payload.get('schemaVersion') != 1:
            return 'unknown'
        weather = payload['weather']
        age = (now - utc(weather['fetchedAt'])).total_seconds()
        if weather.get('status') not in ('ok', 'partial') or weather.get('stale') is not False or not 0 <= age < 900:
            return 'unknown'
        first = start.replace(minute=0, second=0, microsecond=0)
        required = []
        while first < end:
            required.append(first)
            first += timedelta(hours=1)
        if not 1 <= len(required) <= 2:
            return 'unknown'
        hours = {}
        for hour in weather['hours']:
            at = utc(hour['time'])
            if at in hours:  # Conflicting coverage is not safe to suppress.
                return 'unknown'
            hours[at] = hour
        if any(at not in hours for at in required):
            return 'unknown'
        selected = [hours[at] for at in required]
        chances = [percent(h.get('precipitationChancePercent')) for h in selected]
        rainy = [h.get('conditionCode') in RAIN_CONDITIONS for h in selected]
        # High confidence is a product threshold, not a guarantee of observed rain.
        # Require every overlapping hour to agree before suppressing the pass.
        if all(rain and chance is not None and chance >= 80 for rain, chance in zip(rainy, chances)):
            return 'rain'
        # Cloud fraction alone cannot describe fog/smoke, and precipitation
        # probability includes snow. Keep unsupported viewing conditions neutral.
        if any(h.get('conditionCode') in OTHER_VISIBILITY_CONDITIONS for h in selected):
            return 'unknown'
        if any(rainy) or any(p is not None and p >= 30 for p in chances):
            return 'possible_rain'
        clouds = [percent(h.get('cloudCoverPercent')) for h in selected]
        if any(p is None for p in clouds) or any(p is None for p in chances):
            return 'unknown'
        cover = max(clouds)
        return 'mostly_cloudy' if cover >= 70 else 'cloudy' if cover >= 30 else 'clear'
    except (KeyError, TypeError, ValueError, AttributeError, OverflowError):
        return 'unknown'


def weather_for_pass(transit, observer, now):
    window = visible_window(transit)
    if not WEATHER_URL or window is None:
        return 'unknown'
    start, end, _, _ = window
    # A delayed alert whose useful start is in a previous hour stays neutral.
    hour = start.replace(minute=0, second=0, microsecond=0)
    if hour < now.replace(minute=0, second=0, microsecond=0) or hour > now + timedelta(hours=72):
        return 'unknown'
    try:
        token = id_token.fetch_id_token(AuthRequest(), WEATHER_URL)
        query = urlencode({'latitude': observer['lat'], 'longitude': observer['lon'],
                           'start': hour.isoformat(), 'hours': 2})
        req = Request(WEATHER_URL + '/?' + query, headers={'Authorization': 'Bearer ' + token})
        with urlopen(req, timeout=20) as response:
            raw = response.read(65_537)
        if len(raw) > 65_536:
            return 'unknown'
        # Measure freshness after the lookup, including cold-start latency.
        return classify_weather(json.loads(raw), start, end, datetime.now(timezone.utc))
    except Exception:
        # Weather availability must never block a useful orbital reminder.
        return 'unknown'
