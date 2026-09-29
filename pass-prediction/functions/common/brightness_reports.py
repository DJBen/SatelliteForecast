"""Private brightness observations. Never log report bodies or device tokens."""
import hashlib
import math
import re
import time
from datetime import datetime, timezone
from firebase_admin import app_check, firestore

COLLECTION = 'satellite_brightness_reports'


def validate(body, now):
    if not isinstance(body, dict):
        raise ValueError('body')
    report_id = body.get('id')
    if not isinstance(report_id, str) or not re.fullmatch(r'[a-fA-F0-9-]{36}', report_id):
        raise ValueError('id')
    norad = body.get('noradID')
    if type(norad) is not int or not 1 <= norad <= 999999999:
        raise ValueError('satellite')
    magnitude = body.get('magnitude')
    observed = body.get('observedAt')
    for value in (magnitude, observed):
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError('number')
    if not 0 <= magnitude <= 5 or not now - 86400 <= observed <= now + 300:
        raise ValueError('range')
    installation = body.get('installationID')
    if not isinstance(installation, str) or not re.fullmatch(r'[a-fA-F0-9-]{36}', installation):
        raise ValueError('installation')
    token = body.get('fcmToken')
    if not isinstance(token, str) or not 20 <= len(token) <= 4096 or any(c.isspace() for c in token):
        raise ValueError('token')
    reporter = installation.lower()
    return report_id.lower(), reporter, {
        'norad_id': norad, 'magnitude': float(magnitude),
        'observed_at': datetime.fromtimestamp(observed, timezone.utc),
        'reporter_id': reporter, 'fcm_token': token, 'schema_version': 1,
    }


@firestore.transactional
def store(transaction, report_ref, limit_ref, value, now):
    existing = report_ref.get(transaction=transaction)
    limit = limit_ref.get(transaction=transaction).to_dict() or {}
    if existing.exists:
        previous = existing.to_dict()
        if any(previous.get(k) != value[k] for k in ('norad_id', 'magnitude', 'observed_at', 'reporter_id')):
            raise ValueError('conflict')
        return
    window = int(now // 60)
    count = limit.get('count', 0) if limit.get('window') == window else 0
    if count >= 10:
        raise OverflowError('rate')
    transaction.set(report_ref, {**value, 'received_at': firestore.SERVER_TIMESTAMP})
    transaction.set(limit_ref, {'window': window, 'count': count + 1})


def handle_report(request, db):
    if request.method != 'POST':
        return ('Method not allowed', 405)
    if request.content_length is None or request.content_length > 8192:
        return ('Invalid request', 400)
    try:
        app_check.verify_token(request.headers.get('X-Firebase-AppCheck', ''))
    except Exception:
        return ('App attestation required', 401)
    try:
        now = time.time()
        report_id, reporter, value = validate(request.get_json(silent=True), now)
        # Namespace IDs by installation so one reporter cannot claim another's retry ID.
        key = hashlib.sha256(f'{reporter}:{report_id}'.encode()).hexdigest()
        store(db.transaction(), db.collection(COLLECTION).document(key),
              db.collection('brightness_report_limits').document(reporter), value, now)
        return ('', 204)
    except (ValueError, TypeError, KeyError):
        return ('Invalid report', 400)
    except OverflowError:
        return ('Please try again later', 429)
    except Exception:
        return ('Unable to save report', 503)
