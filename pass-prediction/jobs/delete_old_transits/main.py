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

# Retrieve Job-defined env vars
TASK_INDEX = os.getenv("CLOUD_RUN_TASK_INDEX", 0)
TASK_ATTEMPT = os.getenv("CLOUD_RUN_TASK_ATTEMPT", 0)
_, PROJECT_ID = google.auth.default()
LOCATION = os.getenv("GCP_LOCATION", "us-central1")
QUEUE = "pass-notifications"
NOTIFY_ENDPOINT = "https://notify-iglinlck2a-uc.a.run.app"
NOTIFY_PROMINENT_ENDPOINT = "https://notify_prominent-iglinlck2a-uc.a.run.app"

def delete_old_transits(db: google_firestore.Client, cutoff_time: datetime) -> int:
    """
    Deletes all transit records where the document ID (timestamp) is older than cutoff_time.
    Returns the number of records deleted.
    """
    total_deleted = 0
    cutoff_time_str = cutoff_time.strftime('%Y-%m-%dT%H:%M:%S')
    
    print(f"Deleting transit records older than {cutoff_time_str}")
    
    # Get all documents in the transits collection
    transits_collection = db.collection('transits')
    transit_docs = transits_collection.stream()
    
    for transit_doc in transit_docs:
        transit_id = transit_doc.id
        print(f"Processing transit document: {transit_id}")
        
        # Get all records in the subcollection
        records_ref = transit_doc.reference.collection('records')
        records = records_ref.stream()
        
        # Collect records to delete (those older than cutoff_time)
        records_to_delete = []
        
        for record in records:
            record_id = record.id  # This is the timestamp string like "2025-07-10T08:58:11"
            
            try:
                # Parse the timestamp from the document ID
                record_time = datetime.fromisoformat(record_id)
                
                # Ensure record_time is timezone-aware (assume UTC if no timezone info)
                if record_time.tzinfo is None:
                    record_time = record_time.replace(tzinfo=timezone.utc)
                
                # Compare with cutoff time
                if record_time < cutoff_time:
                    records_to_delete.append(record.reference)
                    print(f"  Marking for deletion: {record_id} (older than {cutoff_time_str})")
                    
            except (ValueError, AttributeError) as e:
                print(f"  Warning: Could not parse timestamp from record ID '{record_id}': {e}")
                continue
        
        # Delete records in batches (Firestore batch limit is 500)
        batch_size = 500
        for i in range(0, len(records_to_delete), batch_size):
            batch = db.batch()
            batch_records = records_to_delete[i:i + batch_size]
            
            for record_ref in batch_records:
                batch.delete(record_ref)
            
            # Execute the batch
            batch.commit()
            total_deleted += len(batch_records)
            print(f"  Deleted batch of {len(batch_records)} records from {transit_id}")
    
    return total_deleted

def main():
    try:
        # Initialize Firestore Client
        _, project_id = google.auth.default()
        db = google_firestore.Client(project=project_id)
        
        # Calculate cutoff time (1 day ago)
        now = datetime.now(timezone.utc)
        cutoff_time = now - timedelta(days=1)
        
        print(f"Starting cleanup job - deleting transit records older than {cutoff_time.strftime('%Y-%m-%dT%H:%M:%S')}")
        
        # Delete old transits
        deleted_count = delete_old_transits(db, cutoff_time)
        
        # Log results
        success_message = f"Cleanup completed successfully. Deleted {deleted_count} transit records older than 1 day."
        print(json.dumps({"message": success_message, "severity": "INFO", "deleted_count": deleted_count}))
        
    except Exception as e:
        print(f"Failed to initialize Firestore client: {e}", file=sys.stderr)
        sys.exit(1)


# Start script
if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        message = f"Task #{TASK_INDEX}, Attempt #{TASK_ATTEMPT} failed: {str(err)}"
        print(json.dumps({"message": message, "severity": "ERROR"}))
        sys.exit(1)