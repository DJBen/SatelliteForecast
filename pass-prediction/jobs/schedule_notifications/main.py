"""Reconcile a rolling notification window. Repeated/overlapping runs are safe."""
import hashlib
import json
import math
from datetime import datetime, timedelta, timezone

import google.auth
import pygeohash
from google.api_core.exceptions import AlreadyExists
from google.cloud import firestore, tasks_v2
from google.protobuf import timestamp_pb2

LOCATION = 'us-central1'
QUEUE = 'pass-notifications'
ENDPOINTS = {'regular': 'https://notify-iglinlck2a-uc.a.run.app',
             'prominent': 'https://notify-prominent-iglinlck2a-uc.a.run.app'}
COLLECTIONS = {'regular': 'scheduled_notifications', 'prominent': 'scheduled_prominent_notifications'}


def utc(value):
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def schedule_for(transit, offset, kind):
    peak = utc(transit['culmination']['time'])
    elevation = float(transit.get('visible_culmination_elev', 0))
    if not math.isfinite(elevation) or elevation < 20:
        return None
    if kind == 'regular':
        return peak - timedelta(minutes=5)
    local_peak = peak + timedelta(seconds=offset)
    if elevation < 60 or transit.get('visible_above_10_deg_duration_sec', 0) < 180 or local_peak.hour < 12:
        return None
    due = local_peak.replace(hour=16, minute=0, second=0, microsecond=0) - timedelta(seconds=offset)
    return due if due < peak else None


def fetch_transits(db, sat_id, region, now):
    parent = db.collection('prediction_cache').document(f'{sat_id}_{region}')
    coverage = parent.get().to_dict() or {}
    if coverage.get('schema_version') == 2:
        if utc(coverage['scan_end_time']) <= now or utc(coverage['generated_at']) < now - timedelta(days=2):
            raise RuntimeError('prediction_coverage_stale')
        docs = parent.collection('records').where(filter=firestore.FieldFilter('culmination_at', '>', now)).where(
            filter=firestore.FieldFilter('culmination_at', '<=', now + timedelta(hours=25))).stream()
        schema = 2
    else:
        # Transitional read compatibility while the initial queue catches up.
        docs = db.collection('transits').document(f'{sat_id}_{region}').collection('records').stream()
        schema = 1
    result = []
    for doc in docs:
        record = doc.to_dict()
        peak = utc(record['transit']['culmination']['time'])
        if now < peak <= now + timedelta(hours=25):
            result.append((doc.id, record['transit'], schema))
    return result


@firestore.transactional
def plan(transaction, ref, values):
    existing = ref.get(transaction=transaction).to_dict() or {}
    if existing.get('status') in ('sent', 'skipped', 'unregistered'):
        return False
    # Legacy tasks already in flight keep their existing schedule during migration.
    if existing.get('task_id') and existing.get('scheduler_version') != 2:
        return False
    if existing.get('lease_until') and utc(existing['lease_until']) > datetime.now(timezone.utc):
        return False
    transaction.set(ref, values, merge=True)
    return True


def schedule_user(db, client, project, token, data, region, transits, now):
    if data.get('notifications_disabled'):
        return 0
    try:
        offset = int(data['tzOffset'])
        if not -50400 <= offset <= 50400:
            return 0
    except (KeyError, TypeError, ValueError):
        return 0
    count = 0
    for sat_id, passes in transits.items():
        for pass_id, transit, schema in passes:
            peak = utc(transit['culmination']['time'])
            for kind in ('regular', 'prominent'):
                due = schedule_for(transit, offset, kind)
                if due is None or not now < due <= now + timedelta(hours=24):
                    continue
                document_id = f'{sat_id}_{pass_id}'
                identity = f'{token}:{kind}:{document_id}:{due.isoformat()}'
                task_id = hashlib.sha256(identity.encode()).hexdigest()
                ref = db.collection(COLLECTIONS[kind]).document(token).collection('tasks').document(document_id)
                values = {'task_id': task_id, 'status': 'planned', 'scheduler_version': 2,
                          'schedule_time': due, 'pass_time': peak, 'region': region,
                          'expires_at': peak + timedelta(days=7)}
                if not plan(db.transaction(), ref, values):
                    continue
                payload = {'push_token': token, 'sat_id': sat_id, 'transit': transit,
                           'tz_offset': offset, 'geo_hash_5': region, 'pass_id': pass_id,
                           'cache_schema': schema, 'notification_id': document_id}
                stamp = timestamp_pb2.Timestamp()
                stamp.FromDatetime(due)
                parent = client.queue_path(project, LOCATION, QUEUE)
                task = {'name': f'{parent}/tasks/{task_id}', 'schedule_time': stamp,
                        'http_request': {'http_method': tasks_v2.HttpMethod.POST, 'url': ENDPOINTS[kind],
                                         'headers': {'Content-Type': 'application/json'},
                                         'body': json.dumps(payload).encode()}}
                try:
                    client.create_task(parent=parent, task=task)
                except AlreadyExists:
                    pass
                # Keep the planned receipt even if task creation or this process fails;
                # reconciliation retries the deterministic task name on the next run.
                count += 1
    return count


def main():
    _, project = google.auth.default()
    db, client = firestore.Client(project=project), tasks_v2.CloudTasksClient()
    now = datetime.now(timezone.utc)
    cursor = None
    cache = {}
    counts = {'users': 0, 'tasks_reconciled': 0, 'invalid_users': 0, 'errors': 0}
    while True:
        query = db.collection('users').select(['lat', 'lon', 'geoHash5', 'tzOffset', 'notifications_disabled']).order_by('__name__').limit(250)
        if cursor:
            query = query.start_after(cursor)
        docs = list(query.stream())
        if not docs:
            break
        for doc in docs:
            counts['users'] += 1
            data = doc.to_dict()
            if data.get('notifications_disabled'):
                continue
            try:
                lat, lon = float(data['lat']), float(data['lon'])
                if not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
                    raise ValueError('invalid_location')
                region = pygeohash.encode(lat, lon, precision=5)
            except (KeyError, TypeError, ValueError):
                counts['invalid_users'] += 1
                continue
            try:
                if region not in cache:
                    cache[region] = {sat: fetch_transits(db, sat, region, now) for sat in ('25544', '48274')}
                counts['tasks_reconciled'] += schedule_user(db, client, project, doc.id, data, region, cache[region], now)
            except Exception as error:
                counts['errors'] += 1
                print(json.dumps({'severity': 'ERROR', 'message': 'notification_reconciliation_failed',
                                  'error_type': type(error).__name__}), flush=True)
        cursor = docs[-1]
    db.collection('backend_health').document('notification_scheduler').set({
        **counts, 'completed_at': firestore.SERVER_TIMESTAMP})
    print(json.dumps({'severity': 'INFO', 'message': 'notification_reconciliation_completed', **counts}), flush=True)
    if counts['errors']:
        raise RuntimeError('notification_reconciliation_incomplete')


if __name__ == '__main__':
    main()
