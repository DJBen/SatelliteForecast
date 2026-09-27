"""Eligibility for server alerts; independent of product analytics."""
from datetime import datetime, timedelta, timezone

# Fixed migration deadline: redeploying must never extend legacy eligibility.
LEGACY_GRACE_UNTIL = datetime(2026, 10, 8, tzinfo=timezone.utc)
USER_FIELDS = ['lat', 'lon', 'geoHash5', 'tzOffset', 'locale',
               'notifications_disabled', 'lastAppLaunch', 'appVariant']


def eligible_user(data, now):
    if data.get('notifications_disabled') or data.get('appVariant') in ('test', 'ui-test', 'snapshot', 'preview'):
        return False
    launch = data.get('lastAppLaunch')
    if launch is None:
        return now < LEGACY_GRACE_UNTIL
    try:
        if isinstance(launch, str):
            launch = datetime.fromisoformat(launch.replace('Z', '+00:00'))
        if launch.tzinfo is None:
            launch = launch.replace(tzinfo=timezone.utc)
        return now - timedelta(days=30) <= launch <= now + timedelta(days=1)
    except (TypeError, ValueError, AttributeError):
        return False
