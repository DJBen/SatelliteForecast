
from google.cloud import tasks_v2
from firebase_admin import firestore
import google.auth
import json

# Configuration for the new processing task
_, PROJECT_ID = google.auth.default()

def cancel_and_delete_previous_tasks(db: firestore.Client, push_token: str, cloud_task_client: tasks_v2.CloudTasksClient):
    """
    Cancels and deletes previous tasks for a user from Cloud Tasks and Firestore.
    """
    scheduled_tasks_ref = db.collection('users').document(push_token).collection('scheduled_pass_processor_tasks')
    docs_to_delete_from_firestore = []

    for task_doc in scheduled_tasks_ref.stream():
        task_name_to_delete = task_doc.id  # Assuming the document ID is the full task name
        print(f"Attempting to cancel and delete previous task: {task_name_to_delete} for user {push_token}")
        try:
            cloud_task_client.delete_task(name=task_name_to_delete)
            print(f"Successfully deleted task {task_name_to_delete} from Cloud Tasks.")
            docs_to_delete_from_firestore.append(task_doc.reference)  # Collect reference to delete later
        except tasks_v2.types.Task.DoesNotExist: # Corrected exception type
            print(f"Task {task_name_to_delete} not found in Cloud Tasks, possibly already executed or deleted.")
            docs_to_delete_from_firestore.append(task_doc.reference)  # Still remove from Firestore
        except Exception as e:
            print(f"Error deleting task {task_name_to_delete} from Cloud Tasks: {e}. It might be removed from Firestore anyway or retried.")
            # For now, we'll add it to be deleted from Firestore to avoid re-processing a failed deletion.
            docs_to_delete_from_firestore.append(task_doc.reference)

    # Batch delete from Firestore after iterating
    if docs_to_delete_from_firestore:
        batch = db.batch()
        for doc_ref in docs_to_delete_from_firestore:
            batch.delete(doc_ref)
        batch.commit()
        print(f"Cleaned up {len(docs_to_delete_from_firestore)} old task entries from Firestore for user {push_token}.")


def create_new_processing_task(
    push_token: str,
    new_lat: float,
    new_lon: float,
    new_alt: float,
    geohash_5: str,
    reason: str,
    pass_processor_url: str,
    pass_processor_queue_name: str,
    pass_processor_region: str,
    cloud_task_client: tasks_v2.CloudTasksClient,
    db: firestore.Client
):
    """
    Creates a new pass processing task and stores its reference in Firestore.
    """
    payload_for_processor = {
        "push_token": push_token,
        "lat": new_lat,
        "lon": new_lon,
        "alt": new_alt,
        "geohash_5": geohash_5,
        "satellite_ids": [25544, 48274],  # ISS and Tianhe
        "reason_for_compute": reason
    }

    try:
        print(f"Creating new pass processing task for {push_token} targeting {pass_processor_url} in queue {pass_processor_queue_name}")
        
        # Construct the fully qualified queue name.
        parent = cloud_task_client.queue_path(PROJECT_ID, pass_processor_region, pass_processor_queue_name)

        # Construct the request body.
        task = {
            "http_request": {  # Specify the type of request.
                "http_method": tasks_v2.HttpMethod.POST,
                "url": pass_processor_url,
                "headers": {"Content-type": "application/json"},
                "body": json.dumps(payload_for_processor).encode() # Send JSON payload
            }
        }
        # Use the client to send create_task API request.
        response = cloud_task_client.create_task(parent=parent, task=task)
        created_task_name = response.name
        print(f"Successfully created pass processing task: {created_task_name} for user {push_token}")

        # Store the name of the newly created task in Firestore
        scheduled_tasks_ref = db.collection('users').document(push_token).collection('scheduled_pass_processor_tasks')
        new_task_doc_ref = scheduled_tasks_ref.document(created_task_name)
        new_task_doc_ref.set({
            "created_at": firestore.SERVER_TIMESTAMP,
            "payload": payload_for_processor
        })
        print(f"Stored new task {created_task_name} in Firestore for user {push_token}")
        return created_task_name
    except Exception as e:
        print(f"Failed to create pass processing task for {push_token}: {e}")
        # Handle error: log, retry, or raise as appropriate
        return None
