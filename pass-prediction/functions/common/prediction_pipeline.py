"""Bounded, retryable prediction work. No device identifiers enter task payloads/logs."""
import hashlib
import json
import math
import uuid
from datetime import datetime, timedelta, timezone

import pygeohash
from google.api_core.exceptions import AlreadyExists
from google.cloud import firestore, storage, tasks_v2
from google.protobuf import duration_pb2
from firebase_functions import logger

REGION = 'us-central1'
QUEUE = 'pass-predictions'
SERVICE_ACCOUNT = '388502820521-compute@developer.gserviceaccount.com'
WORKER_URL = 'https://us-central1-pass-prediction.cloudfunctions.net/process_prediction_region'


def utc(value):
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def region_for_user(data):
    try:
        lat, lon = float(data['lat']), float(data['lon'])
        if not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
            return None
        return pygeohash.encode(lat, lon, precision=5)
    except (KeyError, TypeError, ValueError):
        return None


def enqueue_region(client, project, region, now=None):
    now = now or datetime.now(timezone.utc)
    # One region per quarter hour, including repeated app-launch writes and retries.
    key = hashlib.sha256(f'{region}:{int(now.timestamp()) // 900}'.encode()).hexdigest()
    parent = client.queue_path(project, REGION, QUEUE)
    task = {'name': f'{parent}/tasks/{key}',
            'dispatch_deadline': duration_pb2.Duration(seconds=600),
            'http_request': {'http_method': tasks_v2.HttpMethod.POST, 'url': WORKER_URL,
                             'headers': {'Content-Type': 'application/json'},
                             'body': json.dumps({'region': region}).encode(),
                             'oidc_token': {'service_account_email': SERVICE_ACCOUNT,
                                            'audience': WORKER_URL}}}
    try:
        client.create_task(parent=parent, task=task)
        return True
    except AlreadyExists:
        return False


def coverage_is_fresh(data, source_hash, now):
    return (data.get('schema_version') == 2 and data.get('source_hash') == source_hash
            and utc(data['scan_end_time']) >= now + timedelta(days=2)
            and utc(data['generated_at']) >= now - timedelta(hours=12))


@firestore.transactional
def acquire(transaction, ref, source_hash, now, owner):
    data = ref.get(transaction=transaction).to_dict() or {}
    if coverage_is_fresh(data, source_hash, now):
        return 'fresh'
    if data.get('lease_until') and utc(data['lease_until']) > now:
        return 'busy'
    transaction.set(ref, {'lease_owner': owner, 'lease_until': now + timedelta(minutes=5)}, merge=True)
    return 'acquired'


def match_pass_ids(transits, old_records, sat_id):
    """Keep identity across small TLE timing corrections; stations orbit ~90 minutes apart."""
    available = list(old_records)
    result = []
    for transit in transits:
        # The orbital solver can return a short grazing pass without a peak.
        # Such a record cannot be scheduled; preserve the legacy writer's filter.
        peak_time = transit.get('culmination', {}).get('time')
        if not peak_time:
            continue
        peak = utc(peak_time)
        matches = [(abs((utc(data['transit']['culmination']['time']) - peak).total_seconds()), key)
                   for key, data in available if data.get('transit', {}).get('culmination', {}).get('time')]
        closest = min(matches, default=(float('inf'), None))
        if closest[0] <= 600:
            pass_id = closest[1]
            available = [(key, data) for key, data in available if key != pass_id]
        else:
            pass_id = hashlib.sha256(f'{sat_id}:{peak.isoformat()}'.encode()).hexdigest()[:32]
        result.append((pass_id, transit, peak))
    return result


def refresh_region(db, region, predict, storage_client=None):
    storage_client = storage_client or storage.Client()
    lat, lon = pygeohash.decode(region)
    updated = 0
    for sat_id in ('25544', '48274'):
        now = datetime.now(timezone.utc)
        blob = storage_client.bucket('pass-prediction_tle').get_blob(f'tle_{sat_id}.txt')
        if blob is None or now - blob.updated > timedelta(days=7):
            raise RuntimeError('orbital_cache_unavailable')
        raw = blob.download_as_text(if_generation_match=blob.generation)
        source_hash = hashlib.sha256(raw.encode()).hexdigest()
        ref = db.collection('prediction_cache').document(f'{sat_id}_{region}')
        owner = uuid.uuid4().hex
        decision = acquire(db.transaction(), ref, source_hash, now, owner)
        if decision == 'fresh':
            continue
        if decision == 'busy':
            raise RuntimeError('prediction_lease_busy')
        lines = raw.strip().splitlines()
        end = now + timedelta(days=7)
        transits = predict(lines[1], lines[2], lat, lon, 0,
                           start_time_str=now.isoformat(), end_time_str=end.isoformat())
        if not isinstance(transits, list):
            raise RuntimeError('prediction_failed')
        old = list(ref.collection('records').stream())
        identities = [(doc.id, doc.to_dict()) for doc in old]
        if not old:
            # Preserve existing pass identity when moving from the legacy collection.
            identities = [(doc.id, doc.to_dict()) for doc in
                          db.collection('transits').document(f'{sat_id}_{region}').collection('records').stream()]
        matched = match_pass_ids(transits, identities, sat_id)
        if len(matched) != len(transits):
            logger.warn('prediction_incomplete_passes_skipped', count=len(transits) - len(matched))
        if len(old) + len(matched) + 1 > 450:
            raise RuntimeError('prediction_batch_too_large')
        snapshot = ref.get()
        if snapshot.to_dict().get('lease_owner') != owner:
            raise RuntimeError('prediction_lease_lost')
        batch = db.batch()
        next_ids = {pass_id for pass_id, _, _ in matched}
        for doc in old:
            if doc.id not in next_ids:
                batch.delete(doc.reference)
        for pass_id, transit, peak in matched:
            batch.set(ref.collection('records').document(pass_id), {
                'transit': transit, 'pass_id': pass_id, 'culmination_at': peak,
                'created_at': firestore.SERVER_TIMESTAMP, 'expires_at': peak + timedelta(days=2)})
        # Preconditions protect against a worker whose lease expired while it was calculating.
        batch.update(ref, {'schema_version': 2, 'source_hash': source_hash,
                          'source_updated_at': blob.updated, 'scan_end_time': end,
                          'generated_at': now, 'lease_owner': None, 'lease_until': None},
                     option=db.write_option(last_update_time=snapshot.update_time))
        batch.commit()
        updated += 1
    return updated
