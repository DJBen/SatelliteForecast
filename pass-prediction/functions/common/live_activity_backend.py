"""App-Check protected registration and private Cloud Tasks delivery.

Never log payloads or exceptions: they can contain device tokens.
"""
import hashlib
import hmac
import json
import re
import time
from datetime import datetime, timezone

from firebase_admin import app_check, firestore, messaging
from google.api_core.exceptions import AlreadyExists, NotFound
from google.cloud import tasks_v2
from google.protobuf.timestamp_pb2 import Timestamp
from common.live_activity import validate_schedule, boundaries, aps_payload

COLLECTION = 'station_live_activities'
QUEUE = 'station-live-activities'
REGION = 'us-central1'
# Cloud Run IAM requires the service URI as the OIDC audience, not its Functions alias.
DELIVERY_URL = 'https://deliver-live-activity-iglinlck2a-uc.a.run.app'


def identity(value):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9-]{16,128}', value):
        raise ValueError('identity')
    return value


def secret_hash(value):
    identity(value)
    return hashlib.sha256(value.encode()).hexdigest()


def task_name(client, project, activity_id, due):
    parent = client.queue_path(project, REGION, QUEUE)
    key = hashlib.sha256(f'{activity_id}:{due}'.encode()).hexdigest()
    return f'{parent}/tasks/{key}'


def enqueue(client, project, activity_id, due):
    stamp = Timestamp()
    stamp.FromDatetime(datetime.fromtimestamp(due, timezone.utc))
    url = DELIVERY_URL
    task = {'name': task_name(client, project, activity_id, due), 'schedule_time': stamp,
            'http_request': {'http_method': tasks_v2.HttpMethod.POST, 'url': url,
                'headers': {'Content-Type': 'application/json'},
                'oidc_token': {'service_account_email': f'live-activity-tasks@{project}.iam.gserviceaccount.com',
                               'audience': url},
                'body': json.dumps({'id': activity_id}).encode()}}
    try:
        client.create_task(parent=client.queue_path(project, REGION, QUEUE), task=task)
    except AlreadyExists:
        pass


@firestore.transactional
def register(transaction, ref, body, now):
    existing = ref.get(transaction=transaction).to_dict()
    digest = secret_hash(body['secret'])
    if existing and not hmac.compare_digest(existing.get('secret_hash', ''), digest):
        raise PermissionError()
    if body.get('cancel'):
        # Keep a tombstone so late registration retries cannot resurrect this activity.
        value = {'secret_hash': digest, 'cancelled': True,
                 'expires_at': datetime.fromtimestamp(now + 172800, timezone.utc)}
        if existing:
            value['schedule'] = existing.get('schedule')
        transaction.set(ref, value)
        return existing, False
    if existing and existing.get('cancelled'):
        return existing, False
    schedule = validate_schedule(body['schedule'], now)
    if existing and existing['schedule'] != schedule:
        raise ValueError('immutable_schedule')
    token, fcm = body['activityToken'], body['fcmToken']
    if not isinstance(token, str) or not re.fullmatch(r'[a-f0-9]{32,1024}', token):
        raise ValueError('token')
    if not isinstance(fcm, str) or not 20 <= len(fcm) <= 4096:
        raise ValueError('fcm')
    # Monotonic revision prevents an older network request restoring rotated tokens.
    revision = body['revision']
    if isinstance(revision, bool) or not isinstance(revision, int) or not (now - 172800) * 1000 <= revision <= (now + 60) * 1000:
        raise ValueError('revision')
    if existing and revision < existing.get('revision', 0):
        return existing, False
    value = {'secret_hash': digest, 'cancelled': False, 'schedule': schedule,
             'activity_token': token, 'fcm_token': fcm, 'revision': revision,
             'expires_at': datetime.fromtimestamp(schedule['set'] + 86400, timezone.utc)}
    transaction.set(ref, value, merge=True)
    return value, True


def handle_registration(request, db, client, project):
    if request.method != 'POST' or request.content_length is None or request.content_length > 16384:
        return ('Invalid request', 400)
    try:
        app_check.verify_token(request.headers.get('X-Firebase-AppCheck', ''))
    except Exception:
        return ('App attestation required', 401)
    try:
        body = request.get_json()
        activity_id = identity(body['id'])
        now = time.time()
        ref = db.collection(COLLECTION).document(activity_id)
        value, active = register(db.transaction(), ref, body, now)
        if active:
            # Immediate catch-up handles late token issuance and app relaunch.
            # Revision provides a deterministic catch-up task, safe on HTTP retries.
            enqueue(client, project, activity_id, float(body['revision']) / 1000)
            for due in boundaries(value['schedule']):
                if due > now:
                    enqueue(client, project, activity_id, due)
        elif body.get('cancel') and value and value.get('schedule'):
            for due in boundaries(value['schedule']):
                try:
                    client.delete_task(name=task_name(client, project, activity_id, due))
                except NotFound:
                    pass
        return ('', 204)
    except PermissionError:
        return ('Forbidden', 403)
    except (KeyError, ValueError, TypeError):
        return ('Invalid request', 400)
    except Exception:
        return ('Try again', 503)


def handle_delivery(request, db):
    # Cloud Run IAM verifies the task's OIDC token before this handler is invoked.
    try:
        activity_id = identity(request.get_json()['id'])
    except (KeyError, ValueError, TypeError):
        return ('Invalid request', 400)
    ref = db.collection(COLLECTION).document(activity_id)
    value = ref.get().to_dict()
    now = time.time()
    if not value or value.get('cancelled') or now > value['schedule']['set'] + 3600:
        return ('', 204)
    aps = aps_payload(value['schedule'], now)
    message = messaging.Message(token=value['fcm_token'], apns=messaging.APNSConfig(
        live_activity_token=value['activity_token'],
        headers={'apns-push-type': 'liveactivity', 'apns-priority': '10',
                 'apns-topic': 'io.djben.SatelliteForecast.push-type.liveactivity'},
        payload=messaging.APNSPayload(messaging.Aps(custom_data=aps))))
    try:
        messaging.send(message)
        if aps['event'] == 'end':
            retire(db.transaction(), ref, value['revision'])
    except messaging.UnregisteredError:
        # Don't delete newer tokens if a rotation raced this delivery.
        retire(db.transaction(), ref, value['revision'])
    except Exception:
        return ('Try again', 503)
    return ('', 204)


@firestore.transactional
def retire(transaction, ref, revision):
    current = ref.get(transaction=transaction).to_dict() or {}
    if current.get('revision') == revision:
        transaction.update(ref, {'cancelled': True, 'activity_token': firestore.DELETE_FIELD,
                                'fcm_token': firestore.DELETE_FIELD})
