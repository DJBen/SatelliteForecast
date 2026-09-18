# Deploy with `firebase deploy`

from firebase_admin import initialize_app, firestore
from firebase_functions.firestore_fn import (
    on_document_written,
    Event,
    Change
)
from firebase_functions import https_fn, logger, options, scheduler_fn
import os
from google.cloud import tasks_v2
import google.auth
import datetime
import pygeohash as geohash

from common.firestore_helpers import store_transits, previous_scan_end_time
from common.satellite import find_visible_satellite_transits
from common.description import describe_transit, describe_prominent_transit, get_localized_satellite_title
from common.cloud_storage import download_tle_file

app = initialize_app()

# Configuration for the new processing task
_, PROJECT_ID = google.auth.default()

# Initialize Cloud Tasks client once
cloud_task_client = tasks_v2.CloudTasksClient()
db = firestore.client() # Initialize Firestore client once

def _calculate_geohash_5(lat, lon):
    """
    Calculate a 5-character geohash from latitude and longitude coordinates.
    
    Args:
        lat (float): Latitude in degrees
        lon (float): Longitude in degrees
    
    Returns:
        str: 5-character geohash string
    """
    try:
        return geohash.encode(lat, lon, precision=5)
    except Exception as e:
        logger.error(f"Error calculating geohash for lat={lat}, lon={lon}: {e}")
        return None

def _validate_notification_request(request):
    """
    Validates the incoming notification request and extracts common data.
    Returns tuple of (data, task_name, error_response) where error_response is None if valid.
    """
    from flask import jsonify
    
    if request.method != "POST":
        return None, None, (jsonify({"error": "Method not allowed"}), 405)

    data = request.get_json(silent=True)
    logger.info("Received notification data", data=data)

    task_name = request.headers.get("X-CloudTasks-TaskName")
    required_fields = ["push_token", "transit", "sat_id", "tz_offset"]
    if not data or not all(field in data for field in required_fields):
        logger.warn("Missing required fields in notify request", received_data=data)
        return None, None, (jsonify({"error": "Missing required fields. Need: push_token, transit, sat_id, tz_offset"}), 400)

    return data, task_name, None

def _delete_firestore_task(push_token, task_name, collection_name):
    """
    Deletes the corresponding Firestore task document.
    """
    if not task_name or not db:
        return
        
    try:
        tasks_ref = db.collection(collection_name).document(push_token).collection('tasks')
        query = tasks_ref.where("task_id", "==", task_name).limit(1)
        docs = query.stream()
        
        doc_deleted = False
        for doc in docs:
            doc.reference.delete()
            doc_deleted = True
            logger.info(f"Successfully deleted Firestore record for task {task_name} for user {push_token}")
        
        if not doc_deleted:
            logger.warn(f"Firestore record for task {task_name} not found for user {push_token}. Might have been already processed or deleted.")

    except Exception as e:
        logger.warn(f"Error deleting Firestore record for task {task_name} for user {push_token}: {e}")

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

def _get_user_data(push_token):
    """
    Fetches user data from Firestore including location and locale.
    Returns dict with lat, lon, alt, locale or None if not found/error.
    """
    try:
        user_doc = db.collection('users').document(push_token).get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            lat = user_data.get('lat')
            lon = user_data.get('lon')
            alt = user_data.get('alt')
            locale = user_data.get('locale', 'en')  # Default to 'en' if not specified
            
            if lat is not None and lon is not None and alt is not None:
                return {
                    "lat": float(lat),
                    "lon": float(lon),
                    "alt": float(alt),
                    "locale": locale
                }
        
        logger.warn(f"Could not fetch complete location data for user {push_token}")
        return None
    except Exception as e:
        logger.error(f"Error fetching user data for {push_token}: {e}")
        return None

def _send_fcm_notification(push_token, title, body, sat_id=None, observer_data=None):
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
                payload=apns_payload
            )

            message_config["data"] = {
                "noradIndex": sat_id,
                "satelliteCategory": satellite_category,
                "lat": str(observer_data["lat"]),
                "lon": str(observer_data["lon"]),
                "alt": str(observer_data["alt"])
            }
        
        message = messaging.Message(**message_config)
        response = messaging.send(message)
        logger.info(f"Successfully sent FCM message to {push_token}: {response}")
        return True, None
    except messaging.UnregisteredError:
        logger.warn(f"Push token {push_token} is unregistered. Consider removing it from the user's profile.")
        return False, (jsonify({"error": f"Push token {push_token} is unregistered."}), 410)
    except Exception as e:
        logger.error(f"Error sending FCM message to {push_token}: {e}")
        return False, (jsonify({"error": f"Failed to send FCM message: {str(e)}"}), 500)

@on_document_written(document="users/{push_token}", timeout_sec=300, memory=options.MemoryOption.MB_512)
def on_user_location_change(event: Event[Change]) -> None:
    """
    Triggers when a document in the 'users' collection is created or updated.
    Document name is the push token.
    The document should contain fields 'lat', 'lon', 'alt' for location data.
    The 'geoHash5' field is optional and will be calculated from coordinates if missing.
    Enqueues a Cloud Task with the user's push token and location data, if either
    - User is newly created
    - User's geoHash5 has changed

    View logs at https://cloudlogging.app.goo.gl/crdYz1YG9pKaUh919
    """
    push_token = event.params["push_token"]
    
    # Get the new data after the write
    if event.data is None or event.data.after is None or not event.data.after.exists:
        print(f"Document for {push_token} was deleted or does not exist after event.")
        return

    new_data = event.data.after.to_dict()
    if not new_data:
        print(f"Document data is empty for {push_token}.")
        return

    new_lat = new_data.get("lat")
    new_lon = new_data.get("lon")
    new_alt = new_data.get("alt")
    new_geohash_5 = new_data.get("geoHash5")

    if new_lat is None or new_lon is None or new_alt is None:
        print(f"Missing required location data (lat, lon, alt) for {push_token} in new data.")
        return
    
    # Calculate geoHash5 if missing
    if new_geohash_5 is None:
        new_geohash_5 = _calculate_geohash_5(new_lat, new_lon)
        if new_geohash_5 is None:
            print(f"Failed to calculate geoHash5 for {push_token} with lat={new_lat}, lon={new_lon}.")
            return
        print(f"Calculated missing geoHash5 for {push_token}: {new_geohash_5}")

    # Determine if this is a new user or location change
    is_new_user = event.data.before is None or not event.data.before.exists
    location_changed = False
    
    if not is_new_user:
        old_data = event.data.before.to_dict()
        if not old_data:
            print(f"Old document data is empty for {push_token}, treating as new user.")
            is_new_user = True
        else:
            old_geohash_5 = old_data.get("geoHash5")
            # Calculate old geohash if missing
            if old_geohash_5 is None:
                old_lat = old_data.get("lat")
                old_lon = old_data.get("lon")
                if old_lat is not None and old_lon is not None:
                    old_geohash_5 = _calculate_geohash_5(old_lat, old_lon)
                    print(f"Calculated missing old geoHash5 for {push_token}: {old_geohash_5}")
            
            if old_geohash_5 != new_geohash_5:
                print(f"geoHash5 changed for {push_token}: {old_geohash_5} -> {new_geohash_5}")
                location_changed = True
            else:
                print(f"geoHash5 did not change for {push_token} ({new_geohash_5}). Checking scan coverage.")
    
    if is_new_user:
        print(f"User {push_token} is newly created.")
    
    # Process each satellite
    any_computation_needed = False
    computation_reasons = []
    now = datetime.datetime.now(datetime.timezone.utc)
    
    for sat_id in ["25544", "48274"]:
        needs_computation = False
        sat_reason = ""
        start_time_dt = now
        
        if is_new_user:
            needs_computation = True
            sat_reason = "new user"
        elif location_changed:
            needs_computation = True
            sat_reason = f"location changed to {new_geohash_5}"
        else:
            # Check scan coverage for existing user at same location
            last_scan_end = previous_scan_end_time(db, sat_id, new_geohash_5)
            
            if last_scan_end is None:
                needs_computation = True
                sat_reason = f"no previous scan found for satellite {sat_id}"
            else:
                # Convert Firestore Timestamp to datetime if needed
                if hasattr(last_scan_end, 'to_pydatetime'):
                    last_scan_end_dt = last_scan_end.to_pydatetime()
                else:
                    last_scan_end_dt = last_scan_end
                
                # Check if scan end time is less than 2 days away in the future
                delta = last_scan_end_dt - now
                if delta.total_seconds() > 0 and delta.days < 2:
                    # Scan coverage expires soon, extend it
                    needs_computation = True
                    sat_reason = f"scan coverage expires in {delta.days} days (< 2 days)"
                    start_time_dt = last_scan_end_dt
                elif delta.total_seconds() <= 0:
                    # Scan coverage has already expired
                    needs_computation = True
                    sat_reason = f"scan coverage expired {abs(delta.days)} days ago"
                    start_time_dt = last_scan_end_dt
                else:
                    logger.info(f"Scan coverage for satellite {sat_id} and location {new_geohash_5} is good for {delta.days} more days.")
        
        if not needs_computation:
            continue
            
        any_computation_needed = True
        computation_reasons.append(f"{sat_id}: {sat_reason}")
        
        end_time_dt = start_time_dt + datetime.timedelta(days=7)
        start_time_str = start_time_dt.isoformat()
        end_time_str = end_time_dt.isoformat()

        tle_result = download_tle_file(sat_id)
        if tle_result is None:
            logger.error(f"Could not retrieve TLE for satellite {sat_id}. Skipping.")
            continue
        line1, line2 = tle_result

        transits = find_visible_satellite_transits(
            line1, line2,
            new_lat, new_lon, new_alt,
            start_time_str=start_time_str,
            end_time_str=end_time_str,
        )

        if isinstance(transits, dict) and "error" in transits:
            logger.error(f"Error finding transits for {sat_id}: {transits['error']}. Skipping.")
            continue
        logger.info(f"Found {len(transits)} transits for satellite {sat_id}")
        store_transits(db, sat_id, new_geohash_5, end_time_dt, transits)
    
    if any_computation_needed:
        print(f"Computed passes for {push_token} because: {', '.join(computation_reasons)}")
    else:
        print(f"No computation needed for {push_token}. All scan coverage is sufficient.")

@https_fn.on_request()
def notify(request):
    """
    Firebase Function to handle /notify endpoint. Accepts POST requests with JSON body containing
    'push_token', 'title', 'body', and optional 'data'.
    Deletes the corresponding Firestore scheduled notification document if X-CloudTasks-TaskName is present.
    Sends an FCM notification to the user.
    """
    from flask import jsonify
    from firebase_admin import messaging

    try:
        data, task_name, error_response = _validate_notification_request(request)
        if error_response:
            return error_response

        push_token = data["push_token"]
        sat_id = data["sat_id"]
        transit = data["transit"]
        tz_offset = data["tz_offset"]

        # Delete the task from Firestore if task_name is present
        _delete_firestore_task(push_token, task_name, 'scheduled_notifications')

        # Get user data including location and locale
        user_data = _get_user_data(push_token)
        if user_data:
            observer_data = {
                "lat": user_data["lat"],
                "lon": user_data["lon"], 
                "alt": user_data["alt"]
            }
            locale = user_data["locale"]
        else:
            observer_data = None
            locale = "en"  # Default to English if user data not found

        title = get_localized_satellite_title(sat_id, locale=locale, is_rising=True)

        # Send FCM notification
        success, error_response = _send_fcm_notification(push_token, title, describe_transit(transit, tz_offset, locale), sat_id, observer_data)
        if not success:
            return error_response

        return jsonify({"status": "success", "message": "Notification processed and sent"}), 200
    except Exception as e:
        logger.error(f"Error in /notify endpoint: {e}")
        return jsonify({"error": f"Error processing request: {str(e)}"}), 500

@https_fn.on_request()
def notify_prominent(request):
    """
    Firebase Function to handle /notify_prominent endpoint. Accepts POST requests with JSON body containing
    'push_token', 'sat_id', 'transit', and 'tz_offset'.
    Deletes the corresponding Firestore scheduled notification document if X-CloudTasks-TaskName is present.
    Sends an FCM notification to the user.
    """
    from flask import jsonify
    from firebase_admin import messaging

    try:
        data, task_name, error_response = _validate_notification_request(request)
        if error_response:
            return error_response

        push_token = data["push_token"]
        sat_id = data["sat_id"]
        transit = data["transit"]
        tz_offset = data["tz_offset"]

        # Delete the task from Firestore if task_name is present
        _delete_firestore_task(push_token, task_name, 'scheduled_prominent_notifications')

        # Get user data including location and locale
        user_data = _get_user_data(push_token)
        if user_data:
            observer_data = {
                "lat": user_data["lat"],
                "lon": user_data["lon"], 
                "alt": user_data["alt"]
            }
            locale = user_data["locale"]
        else:
            observer_data = None
            locale = "en"  # Default to English if user data not found

        title = get_localized_satellite_title(sat_id, locale=locale, is_rising=False)
        
        # Send FCM notification
        success, error_response = _send_fcm_notification(push_token, title, describe_prominent_transit(sat_id, transit, tz_offset, locale), sat_id, observer_data)
        if not success:
            return error_response

        return jsonify({"status": "success", "message": "Notification processed and sent"}), 200
    except Exception as e:
        logger.error(f"Error in /notify_prominent endpoint: {e}")
        return jsonify({"error": f"Error processing request: {str(e)}"}), 500

@scheduler_fn.on_schedule(schedule="0 0 */3 * *", timeout_sec=1800, memory=options.MemoryOption.GB_1)
def refresh_all_user_transits(event) -> None:
    """
    Scheduled function that runs every 3 days at 00:00 UTC.
    Goes through all users in the 'users' collection and computes satellite transits
    for users who have 'lat', 'lon', and 'alt' fields present.
    Only computes if the previous scan end time is not already 2+ days in the future.
    
    View logs at https://cloudlogging.app.goo.gl/crdYz1YG9pKaUh919
    """
    try:
        logger.info("Starting scheduled refresh of all user transits")
        
        page_size = 100
        cursor = None
        total_users_processed = 0
        total_computations_performed = 0
        
        while True:
            # Query a batch of users
            users_query = db.collection('users').select(['lat', 'lon', 'alt', 'geoHash5']).limit(page_size)
            
            if cursor:
                users_query = users_query.start_after(cursor)
                
            user_docs = list(users_query.stream())
            
            if not user_docs:
                logger.info(f"Finished processing all users. Total: {total_users_processed}, Computations: {total_computations_performed}")
                break  # No more users to process

            # Process the batch
            for user_doc in user_docs:
                try:
                    user_data = user_doc.to_dict()
                    push_token = user_doc.id
                    
                    # Check if user has required location data
                    lat = user_data.get('lat')
                    lon = user_data.get('lon')  
                    alt = user_data.get('alt')
                    geohash_5 = user_data.get('geoHash5')
                    
                    if lat is None or lon is None or alt is None:
                        logger.info(f"Skipping user {push_token} - missing location data")
                        continue
                    
                    # Calculate geoHash5 if missing
                    if geohash_5 is None:
                        geohash_5 = _calculate_geohash_5(lat, lon)
                        if geohash_5 is None:
                            logger.warn(f"Failed to calculate geoHash5 for user {push_token}")
                            continue
                        logger.info(f"Calculated missing geoHash5 for user {push_token}: {geohash_5}")
                    
                    # Check if computation is needed for each satellite
                    user_computation_needed = False
                    computation_reasons = []
                    now = datetime.datetime.now(datetime.timezone.utc)
                    
                    for sat_id in ["25544", "48274"]:
                        needs_computation = False
                        sat_reason = ""
                        start_time_dt = now
                        
                        # Check scan coverage
                        last_scan_end = previous_scan_end_time(db, sat_id, geohash_5)
                        
                        if last_scan_end is None:
                            needs_computation = True
                            sat_reason = f"no previous scan found for satellite {sat_id}"
                            start_time_dt = now
                        else:
                            # Convert Firestore Timestamp to datetime if needed
                            if hasattr(last_scan_end, 'to_pydatetime'):
                                last_scan_end_dt = last_scan_end.to_pydatetime()
                            else:
                                last_scan_end_dt = last_scan_end
                            
                            # Calculate time difference between scan end and now
                            delta = last_scan_end_dt - now
                            
                            if delta.total_seconds() > 0 and delta.total_seconds() >= (2 * 24 * 3600):
                                # Scan coverage is at least 2 days in the future, skip
                                logger.info(f"Scan coverage for satellite {sat_id} and user {push_token} is good for {delta.days} more days (>= 2 days).")
                                needs_computation = False
                            elif delta.total_seconds() > 0 and delta.total_seconds() < (2 * 24 * 3600):
                                # Scan coverage expires within 2 days, extend from scan_end_time
                                needs_computation = True
                                sat_reason = f"scan coverage expires in {delta.total_seconds() / (24 * 3600):.1f} days (< 2 days)"
                                start_time_dt = last_scan_end_dt
                            else:
                                # Scan coverage has already expired, start from now
                                needs_computation = True
                                sat_reason = f"scan coverage expired {abs(delta.total_seconds()) / (24 * 3600):.1f} days ago"
                                start_time_dt = now
                        
                        if not needs_computation:
                            continue
                            
                        user_computation_needed = True
                        computation_reasons.append(f"{sat_id}: {sat_reason}")
                        
                        end_time_dt = start_time_dt + datetime.timedelta(days=3)  # 3 days forward as requested
                        start_time_str = start_time_dt.isoformat()
                        end_time_str = end_time_dt.isoformat()

                        tle_result = download_tle_file(sat_id)
                        if tle_result is None:
                            logger.error(f"Could not retrieve TLE for satellite {sat_id}. Skipping.")
                            continue
                        line1, line2 = tle_result

                        transits = find_visible_satellite_transits(
                            line1, line2,
                            lat, lon, alt,
                            start_time_str=start_time_str,
                            end_time_str=end_time_str,
                        )

                        if isinstance(transits, dict) and "error" in transits:
                            logger.error(f"Error finding transits for {sat_id}: {transits['error']}. Skipping.")
                            continue
                        logger.info(f"Found {len(transits)} transits for satellite {sat_id} for user {push_token}")
                        store_transits(db, sat_id, geohash_5, end_time_dt, transits)
                    
                    if user_computation_needed:
                        logger.info(f"Computed passes for user {push_token} because: {', '.join(computation_reasons)}")
                        total_computations_performed += 1
                    else:
                        logger.info(f"No computation needed for user {push_token}. All scan coverage is sufficient.")
                    
                    total_users_processed += 1
                    
                except Exception as user_error:
                    logger.error(f"Error processing user {push_token}: {user_error}")
                    continue

            # Set the cursor for the next page
            cursor = user_docs[-1]
            logger.info(f"Processed batch of {len(user_docs)} users. Total processed so far: {total_users_processed}")

    except Exception as e:
        logger.error(f"Error in scheduled refresh_all_user_transits function: {e}")
        raise