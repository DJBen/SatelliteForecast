from firebase_admin import firestore
from firebase_functions import logger
from typing import List, Dict, Any
from datetime import datetime, timezone, timedelta

def _round_to_nearest_second(time_str: str) -> str:
    """
    Rounds a time string to the nearest second.
    Input format: 2025-06-29T11:58:28.855
    Output format: 2025-06-29T11:58:29
    """
    try:
        # Parse the datetime string
        dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
        # Round to nearest second
        if dt.microsecond >= 500000:
            dt = dt.replace(microsecond=0) + timedelta(seconds=1)
        else:
            dt = dt.replace(microsecond=0)
        # Return as ISO format without microseconds
        return dt.isoformat()
    except (ValueError, AttributeError):
        # If parsing fails, return original string
        return time_str

def store_transits(db: firestore.Client, sat_id: str, geo_hash_5: str, scan_end_time: datetime, transits: List[Dict[str, Any]]) -> None:
    """
    Writes each transit as a separate record to Firestore under collection 'transits', document '{said_id}_{geo_hash_5}',
    and subcollection 'records'. Uses the culmination.time as the document name for each record.
    If there are existing transits within 15 seconds of a new transit, removes all conflicting existing transits and stores the new one.
    """
    unique_key = f"{sat_id}_{geo_hash_5}"
    doc_ref = db.collection('transits').document(unique_key)
    doc_ref.set({
        'scan_end_time': scan_end_time,
    })
    
    # Get existing records from the subcollection
    existing_records = doc_ref.collection('records').get()
    existing_times = []
    for doc in existing_records:
        doc_name = doc.id  # This is the timestamp-like document name
        try:
            # Parse the existing timestamp
            existing_dt = datetime.fromisoformat(doc_name)
            existing_times.append(existing_dt)
        except (ValueError, AttributeError):
            # Skip if parsing fails
            continue
    
    for transit in transits:
        culmination_time = transit.get('culmination', {}).get('time')
        if not culmination_time:
            continue  # skip if no culmination.time
        
        # Round culmination time to nearest second to avoid conflicts from sub-second differences
        rounded_time = _round_to_nearest_second(str(culmination_time))
        
        # Parse the current transit time for comparison
        try:
            current_dt = datetime.fromisoformat(rounded_time)
            
            # Check if there are any existing transits within 15 seconds and remove them
            transits_to_remove = []
            for i, existing_dt in enumerate(existing_times):
                time_diff = abs((current_dt - existing_dt).total_seconds())
                if time_diff <= 15:
                    # Find the document ID for this existing transit
                    existing_doc_id = existing_dt.isoformat()
                    transits_to_remove.append(existing_doc_id)
            
            # Remove all conflicting existing transits
            for doc_id_to_remove in transits_to_remove:
                try:
                    doc_ref.collection('records').document(doc_id_to_remove).delete()
                    logger.info(f"Removed existing transit at {doc_id_to_remove} for sat_id {sat_id} and geo_hash_5 {geo_hash_5} due to proximity to new transit at {rounded_time}.")
                except Exception as e:
                    logger.error(f"Failed to remove existing transit at {doc_id_to_remove}: {e}")

        except (ValueError, AttributeError):
            # If parsing fails, proceed with adding the record
            pass
        
        record = {
            'transit': transit,
            'created_at': firestore.SERVER_TIMESTAMP
        }
        # Use rounded culmination.time as document name and merge to handle concurrent writes
        doc_ref.collection('records').document(rounded_time).set(record, merge=True)

def previous_scan_end_time(db: firestore.Client, sat_id: str, geo_hash_5: str) -> datetime:
    """
    Fetches the last scan end time for a given sat_id and geo_hash_5.
    Returns the scan end time as a datetime object, or None if not found.
    """
    unique_key = f"{sat_id}_{geo_hash_5}"
    doc_ref = db.collection('transits').document(unique_key)
    doc = doc_ref.get()
    if doc.exists:
        data = doc.to_dict()
        scan_end_time = data.get('scan_end_time')
        if scan_end_time:
            return scan_end_time
    return None 
