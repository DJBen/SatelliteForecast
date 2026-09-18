import json
import os
import sys
from datetime import datetime, timezone, timedelta
from firebase_admin import firestore
import google.auth
from google.cloud import firestore as google_firestore
from google.cloud import tasks_v2
from google.protobuf import timestamp_pb2
from typing import List, Dict, Any
import pygeohash as geohash

# Retrieve Job-defined env vars
TASK_INDEX = os.getenv("CLOUD_RUN_TASK_INDEX", 0)
TASK_ATTEMPT = os.getenv("CLOUD_RUN_TASK_ATTEMPT", 0)
_, PROJECT_ID = google.auth.default()
LOCATION = os.getenv("GCP_LOCATION", "us-central1")
QUEUE = "pass-notifications"
NOTIFY_ENDPOINT = "https://notify-iglinlck2a-uc.a.run.app"
NOTIFY_PROMINENT_ENDPOINT = "https://notify-prominent-iglinlck2a-uc.a.run.app"

def _calculate_geohash_5(lat, lon):
    """
    Calculate a 5-character geohash from latitude and longitude coordinates.
    
    Args:
        lat (float): Latitude in degrees
        lon (float): Longitude in degrees
    
    Returns:
        str: 5-character geohash string or None if calculation fails
    """
    try:
        return geohash.encode(lat, lon, precision=5)
    except Exception as e:
        print(f"Error calculating geohash for lat={lat}, lon={lon}: {e}")
        return None

def create_task(payload: Dict[str, Any], schedule_time: datetime, endpoint: str = NOTIFY_ENDPOINT):
    """Create a task in a Cloud Tasks queue."""
    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(PROJECT_ID, LOCATION, QUEUE)

    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": endpoint,
            "headers": {"Content-type": "application/json"},
            "body": json.dumps(payload, default=str).encode(),
        }
    }

    if schedule_time:
        timestamp = timestamp_pb2.Timestamp()
        timestamp.FromDatetime(schedule_time)
        task["schedule_time"] = timestamp

    response = client.create_task(parent=parent, task=task)
    return response


def fetch_transits(db: firestore.Client, sat_id: str, geo_hash_5: str, window_in_sec: int) -> List[Dict[str, Any]]:
    """
    Fetches all transit records for a given sat_id and geo_hash_5 where culmination time is in the future.
    Returns a list of matching transit records. Assumes document names are culmination.time.
    """
    unique_key = f"{sat_id}_{geo_hash_5}"
    doc_ref = db.collection('transits').document(unique_key)
    records_ref = doc_ref.collection('records')
    # Get current UTC time
    now = datetime.now(timezone.utc)
    end_time = now + timedelta(seconds=window_in_sec)
    current_time_iso = now.isoformat()
    end_time_iso = end_time.isoformat()
    query = records_ref.where('transit.culmination.time', '>', current_time_iso).where('transit.culmination.time', '<=', end_time_iso).order_by('transit.culmination.time', direction=firestore.Query.ASCENDING)
    docs = query.stream()
    transits = []
    for doc in docs:
        transit_data = doc.to_dict()
        transit_data['id'] = doc.id
        transits.append(transit_data)
    return transits

def is_prominent_pass(transit: Dict[str, Any], tz_offset: int) -> bool:
    """
    Determine whether a transit is a prominent pass based on:
    1. happens at PM wrt local timezone
    2. transit['transit']['visible_above_10_deg_duration_sec'] >= 180
    3. transit['transit']['visible_culmination_elev'] >= 60
    """
    try:
        # Check duration and elevation criteria
        duration = transit['transit'].get('visible_above_10_deg_duration_sec', 0)
        elevation = transit['transit'].get('visible_culmination_elev', 0)
        
        if duration < 180 or elevation < 60:
            return False
        
        # Check if it happens in PM local time
        culmination_time_str = transit['transit']['culmination']['time']
        culmination_time = datetime.fromisoformat(culmination_time_str)
        
        # Ensure culmination_time is timezone-aware (assume UTC if no timezone info)
        if culmination_time.tzinfo is None:
            culmination_time = culmination_time.replace(tzinfo=timezone.utc)
        
        # Convert to local time using tz_offset (in seconds)
        local_time = culmination_time + timedelta(seconds=tz_offset)
        
        # Check if it's PM (hour >= 12)
        return local_time.hour >= 12
        
    except (KeyError, ValueError, TypeError) as e:
        print(f"Error checking prominent pass criteria: {e}")
        return False

def get_4pm_schedule_time(transit_date: datetime, tz_offset: int) -> datetime:
    """
    Get the 4pm local time on the day of the transit for scheduling.
    """
    # Ensure transit_date is timezone-aware (assume UTC if no timezone info)
    if transit_date.tzinfo is None:
        transit_date = transit_date.replace(tzinfo=timezone.utc)
    
    # Convert transit time to local time
    local_transit_time = transit_date + timedelta(seconds=tz_offset)
    
    # Get 4pm local time on the same date
    local_4pm = local_transit_time.replace(hour=16, minute=0, second=0, microsecond=0)
    
    # Convert back to UTC for scheduling
    utc_4pm = local_4pm - timedelta(seconds=tz_offset)
    
    return utc_4pm

def main():
    try:
        # Initialize Firestore Client
        _, project_id = google.auth.default()
        db = google_firestore.Client(project=project_id)
    except Exception as e:
        print(f"Failed to initialize Firestore client: {e}", file=sys.stderr)
        sys.exit(1)

    page_size = 100
    # Start with no cursor
    cursor = None
    
    while True:
        # Query a batch of users - include lat and lon for geohash calculation if needed
        users_query = db.collection(u'users').select([u'geoHash5', u'tzOffset', u'lat', u'lon']).order_by("geoHash5").limit(page_size)
        
        if cursor:
            users_query = users_query.start_after(cursor)
            
        user_docs = list(users_query.stream())
        
        if not user_docs:
            break # No more users to process

        # Process the batch
        geohash_users = {}
        for user_doc in user_docs:
            user_data = user_doc.to_dict()
            geohash5 = user_data.get('geoHash5')
            tz_offset = user_data.get('tzOffset')
            lat = user_data.get('lat')
            lon = user_data.get('lon')
            
            # Calculate geohash5 if missing but lat/lon are available
            if not geohash5 and lat is not None and lon is not None:
                try:
                    geohash5 = _calculate_geohash_5(float(lat), float(lon))
                    if geohash5:
                        print(f"Calculated missing geoHash5 for user {user_doc.id}: {geohash5}")
                except (ValueError, TypeError) as e:
                    print(f"Error calculating geohash5 for user {user_doc.id} with lat={lat}, lon={lon}: {e}")
                    continue
            
            if geohash5:
                if geohash5 not in geohash_users:
                    geohash_users[geohash5] = []
                geohash_users[geohash5].append({
                    'user_id': user_doc.id,
                    'tz_offset': tz_offset
                })

        for geohash5, users in geohash_users.items():
            # Fetch all transits for this geohash5 once
            all_transits = {}
            for sat_id in ['25544', '48274']:
                print(f"Fetching transits for sat_id: {sat_id}, geoHash5: {geohash5}")
                transits = fetch_transits(db, sat_id, geohash5, 24 * 3600)
                all_transits[sat_id] = transits

            # Process each user for this geohash5
            for user in users:
                user_id = user['user_id']
                tz_offset = user['tz_offset']
                push_token = user_id

                if not push_token:
                    print(f"User {user_id} has no push token, skipping.")
                    continue
                
                # Get the subcollection for scheduled notifications for this user
                tasks_subcollection_ref = db.collection('scheduled_notifications').document(user_id).collection('tasks')
                prominent_tasks_subcollection_ref = db.collection('scheduled_prominent_notifications').document(user_id).collection('tasks')
                
                # Fetch existing scheduled notification transit_ids for this user
                existing_task_docs = tasks_subcollection_ref.stream()
                existing_task_sat_id_transit_ids = {doc.id for doc in existing_task_docs}
                
                # Fetch existing prominent notification transit_ids for this user
                existing_prominent_task_docs = prominent_tasks_subcollection_ref.stream()
                existing_prominent_task_sat_id_transit_ids = {doc.id for doc in existing_prominent_task_docs}
                
                # Schedule new notifications
                for sat_id, transits in all_transits.items():
                    for transit in transits:
                        transit_id = transit['id']
                        
                        # Schedule regular notification (5 minutes before culmination)
                        if f"{sat_id}_{transit_id}" not in existing_task_sat_id_transit_ids:
                            elevation = transit['transit'].get('visible_culmination_elev', 0)
                            if elevation < 20:
                                print(f"Skipping regular notification for sat {sat_id}, transit {transit_id} - elevation too low ({elevation}°)")
                                continue

                            culmination_time_str = transit['transit']['culmination']['time']
                            culmination_time = datetime.fromisoformat(culmination_time_str)
                            
                            # Ensure culmination_time is timezone-aware (assume UTC if no timezone info)
                            if culmination_time.tzinfo is None:
                                culmination_time = culmination_time.replace(tzinfo=timezone.utc)
                            
                            schedule_time = culmination_time - timedelta(minutes=5)

                            payload = {
                                'push_token': push_token,
                                "sat_id": sat_id,
                                'transit': transit["transit"],
                                'tz_offset': tz_offset,
                            }
                            
                            try:
                                task = create_task(payload, schedule_time, NOTIFY_ENDPOINT)
                                
                                # Extract task ID from the full name
                                task_id = task.name.split('/')[-1]
                                print(f"Created regular task {task_id} for user {user_id}, sat {sat_id}, and transit {transit_id}")
                                # Store task info in subcollection, using {sat_id}_{transit_id} as document_id
                                task_doc_ref = tasks_subcollection_ref.document(f"{sat_id}_{transit_id}")
                                task_doc_ref.set({
                                    'task_id': task_id,
                                })
                            except Exception as e:
                                print(f"Failed to create regular task for user {user_id}, sat {sat_id}, transit {transit_id}: {e}", file=sys.stderr)
                        else:
                            print(f"Regular notification for sat {sat_id}, transit {transit_id} already scheduled for user {user_id}")
                        
                        # Schedule prominent notification (4pm local time) if it meets criteria
                        if (f"{sat_id}_{transit_id}" not in existing_prominent_task_sat_id_transit_ids and 
                            is_prominent_pass(transit, tz_offset)):
                            
                            culmination_time_str = transit['transit']['culmination']['time']
                            culmination_time = datetime.fromisoformat(culmination_time_str)
                            
                            # Ensure culmination_time is timezone-aware (assume UTC if no timezone info)
                            if culmination_time.tzinfo is None:
                                culmination_time = culmination_time.replace(tzinfo=timezone.utc)
                            
                            prominent_schedule_time = get_4pm_schedule_time(culmination_time, tz_offset)

                            # Only schedule if 4pm hasn't passed yet
                            if prominent_schedule_time > datetime.now(timezone.utc):
                                payload = {
                                    'push_token': push_token,
                                    "sat_id": sat_id,
                                    'transit': transit["transit"],
                                    'tz_offset': tz_offset,
                                }
                                
                                try:
                                    task = create_task(payload, prominent_schedule_time, NOTIFY_PROMINENT_ENDPOINT)
                                    
                                    # Extract task ID from the full name
                                    task_id = task.name.split('/')[-1]
                                    print(f"Created prominent task {task_id} for user {user_id}, sat {sat_id}, and transit {transit_id} at 4pm local")
                                    # Store task info in prominent subcollection
                                    prominent_task_doc_ref = prominent_tasks_subcollection_ref.document(f"{sat_id}_{transit_id}")
                                    prominent_task_doc_ref.set({
                                        'task_id': task_id,
                                    })
                                except Exception as e:
                                    print(f"Failed to create prominent task for user {user_id}, sat {sat_id}, transit {transit_id}: {e}", file=sys.stderr)
                            else:
                                print(f"Skipping prominent notification for user {user_id}, sat {sat_id}, transit {transit_id} - 4pm has already passed")

        # Set the cursor for the next page
        cursor = user_docs[-1]


# Start script
if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        message = f"Task #{TASK_INDEX}, Attempt #{TASK_ATTEMPT} failed: {str(err)}"
        print(json.dumps({"message": message, "severity": "ERROR"}))
        sys.exit(1)