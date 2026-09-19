"""FCM data values must be strings. Older clients safely ignore passTime."""
from datetime import datetime, timezone


def pass_time_data(transit):
    value = (transit or {}).get('culmination', {}).get('time')
    if not value:
        return {}
    try:
        time = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if time.tzinfo is None:
            time = time.replace(tzinfo=timezone.utc)
        seconds = time.timestamp()
        if not 946684800 <= seconds <= 4102444800:
            return {}
        return {'passTime': str(seconds)}
    except (TypeError, ValueError, AttributeError, OverflowError):
        return {}
