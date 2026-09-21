# Deploy with `firebase deploy`

from firebase_admin import initialize_app, firestore
from firebase_functions.firestore_fn import (
    on_document_written,
    Event,
    Change
)
from firebase_functions import https_fn, logger, options, scheduler_fn
import hashlib
from google.cloud import tasks_v2
import google.auth
import datetime
import pygeohash as geohash

from common.prediction_pipeline import enqueue_region, region_for_user, refresh_region
from common.satellite import find_visible_satellite_transits
from common.description import describe_transit, describe_prominent_transit, get_localized_satellite_title
from common.deep_link import pass_time_data
from common.delivery import claim_delivery, finish_delivery
from common.prediction_pipeline import utc

app = initialize_app()

# Configuration for the new processing task
_, PROJECT_ID = google.auth.default()

# Initialize Cloud Tasks client once
cloud_task_client = tasks_v2.CloudTasksClient()
db = firestore.client() # Initialize Firestore client once

def _get_satellite_category(sat_id):
    """
    Returns satellite category for APNS payload based on satellite ID.
    """
    if sat_id == "25544":
        return "iss"
    elif sat_id == "48274":
        return "tianhe"
    else:
        return "satellite"

def _send_fcm_notification(push_token, title, body, sat_id=None, observer_data=None, transit=None, collapse_id=None):
    """
    Sends FCM notification and handles common error cases.
    Returns tuple of (success, error_response) where error_response is None if successful.
    """
    from flask import jsonify
    from firebase_admin import messaging
    
    try:
        # Create base message
        message_config = {
            "notification": messaging.Notification(
                title=title,
                body=body,
            ),
            "token": push_token,
        }
        
        # Add APNS configuration if satellite and observer data are provided
        if sat_id and observer_data:
            satellite_category = _get_satellite_category(sat_id)
            
            # Create APNS payload with category and user info
            apns_payload = messaging.APNSPayload(
                aps=messaging.Aps(
                    category="PASS",
                )
            )
            
            message_config["apns"] = messaging.APNSConfig(
                payload=apns_payload,
                headers={"apns-collapse-id": collapse_id} if collapse_id else None
            )

            message_config["data"] = {
                "noradIndex": sat_id,
                "satelliteCategory": satellite_category,
                "lat": str(observer_data["lat"]),
                "lon": str(observer_data["lon"]),
                "alt": str(observer_data["alt"]),
                **pass_time_data(transit)
            }
        
        message = messaging.Message(**message_config)
        response = messaging.send(message)
        logger.info("fcm_accepted")
        return True, None
    except messaging.UnregisteredError:
        logger.info("fcm_unregistered")
        return False, (jsonify({"error": "Device is unregistered"}), 410)
    except Exception as e:
        logger.error("fcm_send_failed", error_type=type(e).__name__)
        return False, (jsonify({"error": "FCM send failed"}), 500)

@on_document_written(document="users/{push_token}", timeout_sec=60)
def on_user_location_change(event: Event[Change]) -> None:
    """Keep app writes fast; queue deduplicated regional work instead of computing inline."""
    if event.data is None or event.data.after is None or not event.data.after.exists:
        return
    data = event.data.after.to_dict() or {}
    region = region_for_user(data)
    if not region or data.get('notifications_disabled'):
        return
    if data.get('geoHash5') != region:
        event.data.after.reference.update({'geoHash5': region})
    enqueue_region(cloud_task_client, PROJECT_ID, region)


@https_fn.on_request(invoker='private', timeout_sec=540, memory=options.MemoryOption.GB_1,
                     concurrency=1, max_instances=20)
def process_prediction_region(request):
    if request.method != 'POST':
        return ('Method not allowed', 405)
    data = request.get_json(silent=True) or {}
    region = data.get('region', '')
    if not isinstance(region, str) or len(region) != 5 or any(c not in '0123456789bcdefghjkmnpqrstuvwxyz' for c in region):
        return ('Invalid region', 400)
    try:
        updated = refresh_region(db, region, find_visible_satellite_transits)
        logger.info('prediction_region_completed', updated_satellites=updated)
        return ('OK', 200)
    except Exception as error:
        logger.error('prediction_region_failed', error_type=type(error).__name__)
        return ('Prediction refresh failed', 503)


def _deliver_notification(request, prominent=False):
    from flask import jsonify
    if request.method != 'POST':
        return ('Method not allowed', 405)
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not all(k in data for k in ('push_token', 'sat_id', 'transit', 'tz_offset')):
        return ('Invalid notification request', 400)
    token, sat_id = data['push_token'], data['sat_id']
    if not isinstance(token, str) or '/' in token or sat_id not in ('25544', '48274'):
        return ('Invalid notification request', 400)
    now = datetime.datetime.now(datetime.timezone.utc)
    collection = 'scheduled_prominent_notifications' if prominent else 'scheduled_notifications'
    records = db.collection(collection).document(token).collection('tasks')
    task_id = (request.headers.get('X-CloudTasks-TaskName') or '').split('/')[-1]
    notification_id = data.get('notification_id')
    if notification_id and (not isinstance(notification_id, str) or '/' in notification_id):
        return ('Invalid notification request', 400)
    ref = records.document(notification_id) if notification_id else None
    if ref is None and task_id:
        matches = list(records.where('task_id', '==', task_id).limit(1).stream())
        ref = matches[0].reference if matches else records.document('legacy_' + hashlib.sha256(task_id.encode()).hexdigest())
    if ref is None:
        # Preserve existing manual diagnostics, but give them a durable receipt too.
        key = hashlib.sha256((sat_id + str(data['transit']) + str(prominent)).encode()).hexdigest()
        ref, task_id = records.document('manual_' + key), key
    try:
        decision = claim_delivery(db.transaction(), ref, task_id, now)
        if decision in ('done', 'superseded'):
            return jsonify({'status': decision}), 200
        if decision == 'busy':
            return ('Delivery already in progress', 503)
        user_ref = db.collection('users').document(token)
        user = user_ref.get().to_dict() or {}
        region = region_for_user(user)
        reason = None
        if not region or user.get('notifications_disabled'):
            reason = 'device_unavailable'
        elif data.get('geo_hash_5') and region != data['geo_hash_5']:
            reason = 'location_changed'
        transit = data['transit']
        if reason is None and data.get('cache_schema') == 2:
            current = db.collection('prediction_cache').document(f'{sat_id}_{region}').collection('records').document(data['pass_id']).get()
            if not current.exists:
                reason = 'pass_removed'
            else:
                transit = current.to_dict()['transit']
        if reason is None:
            peak = utc(transit['culmination']['time'])
            elevation = float(transit.get('visible_culmination_elev', 0))
            if peak <= now:
                reason = 'pass_expired'
            elif elevation < (60 if prominent else 20):
                reason = 'pass_no_longer_qualifies'
            elif not prominent and peak - now > datetime.timedelta(minutes=15):
                reason = 'pass_time_changed'
            elif prominent and transit.get('visible_above_10_deg_duration_sec', 0) < 180:
                reason = 'pass_no_longer_qualifies'
        if reason:
            finish_delivery(ref, 'skipped', now, reason)
            logger.info('notification_skipped', reason=reason)
            return jsonify({'status': 'skipped'}), 200
        locale = user.get('locale', 'en')
        offset = int(user.get('tzOffset', data['tz_offset']))
        title = get_localized_satellite_title(sat_id, locale=locale, is_rising=not prominent)
        body = describe_prominent_transit(sat_id, transit, offset, locale) if prominent else describe_transit(transit, offset, locale)
        observer = {key: float(user.get(key, 0)) for key in ('lat', 'lon', 'alt')}
        success, error_response = _send_fcm_notification(token, title, body, sat_id, observer,
            transit=transit, collapse_id=hashlib.sha256(ref.path.encode()).hexdigest())
        if success:
            finish_delivery(ref, 'sent', now)
            return jsonify({'status': 'sent'}), 200
        if error_response[1] == 410:
            user_ref.update({'notifications_disabled': True, 'notification_disabled_reason': 'unregistered'})
            finish_delivery(ref, 'unregistered', now)
            return jsonify({'status': 'unregistered'}), 200
        ref.set({'status': 'planned', 'lease_until': None}, merge=True)
        return error_response
    except Exception as error:
        logger.error('notification_delivery_failed', error_type=type(error).__name__)
        return ('Notification delivery failed', 500)


@https_fn.on_request()
def notify(request):
    return _deliver_notification(request)


@https_fn.on_request()
def notify_prominent(request):
    return _deliver_notification(request, prominent=True)


@scheduler_fn.on_schedule(schedule="*/15 * * * *", timeout_sec=540,
                          memory=options.MemoryOption.MB_512, max_instances=1,
                          retry_count=2, min_backoff_seconds=60)
def refresh_all_user_transits(event) -> None:
    """Only enumerate and enqueue; independent region failures cannot block other users."""
    regions = set()
    users = 0
    queued = 0
    cursor = None
    while True:
        query = db.collection('users').select(['lat', 'lon', 'geoHash5', 'notifications_disabled']).order_by('__name__').limit(250)
        if cursor:
            query = query.start_after(cursor)
        docs = list(query.stream())
        if not docs:
            break
        for doc in docs:
            users += 1
            data = doc.to_dict()
            region = region_for_user(data)
            if not region or data.get('notifications_disabled'):
                continue
            if data.get('geoHash5') != region:
                doc.reference.update({'geoHash5': region})
            if region not in regions:
                queued += int(enqueue_region(cloud_task_client, PROJECT_ID, region))
                regions.add(region)
        cursor = docs[-1]
    db.collection('backend_health').document('prediction_dispatch').set({
        'completed_at': firestore.SERVER_TIMESTAMP, 'users': users,
        'regions': len(regions), 'queued': queued})
    logger.info('prediction_dispatch_completed', users=users, regions=len(regions), queued=queued)
