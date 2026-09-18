import os
import google.auth
from google.cloud import tasks_v2
import datetime
from google.protobuf import timestamp_pb2
import json # Added for create_task_for_url

QUEUE_NAME = "pass-notifications"
REGION = os.environ.get("REGION", "us-central1")
NOTIFY_URL = f"https://notify-iglinlck2a-uc.a.run.app"
SERVICE_ACCOUNT_EMAIL = "pass-notifier@pass-prediction.iam.gserviceaccount.com"

def schedule_notification(payload, schedule_time=None) -> str:
    """Creates a task in the 'pass-notifications' queue with the given payload.
    
    Args:
        payload: The request body to send (string will be encoded to bytes).
        schedule_time: Optional datetime.datetime for when to execute the task.

    Returns:
        str: The name of the created task.
    """
    client = tasks_v2.CloudTasksClient()
    _, project = google.auth.default()
    parent = client.queue_path(project, REGION, QUEUE_NAME)

    # Construct the task
    task_config = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": NOTIFY_URL,
            "headers": {"Content-Type": "application/json"},
            "body": payload.encode() if isinstance(payload, str) else payload,
            "oidc_token": {
                "service_account_email": SERVICE_ACCOUNT_EMAIL,
            },
        }
    }
    
    # Add schedule time if provided
    if schedule_time:
        timestamp = timestamp_pb2.Timestamp()
        timestamp.FromDatetime(schedule_time)
        task_config["schedule_time"] = timestamp
    
    # Send the request
    response = client.create_task(parent=parent, task=task_config)
    print(f"Created task {response.name} in queue {QUEUE_NAME}.")
    return response.name

def create_task_for_url(
    queue_name: str,
    task_url: str,
    payload_dict: dict,
    project_id: str,
    region: str,
    schedule_time: datetime.datetime = None,
    service_account_email: str = None
) -> str:
    """Creates a task in the specified queue targeting the given URL.

    Args:
        queue_name: The name of the Cloud Tasks queue.
        task_url: The URL the task will call.
        payload_dict: The JSON serializable dictionary payload for the task.
        project_id: GCP project ID.
        region: Region of the Cloud Tasks queue.
        schedule_time: Optional datetime.datetime for when to execute the task.
        service_account_email: Optional service account email for OIDC token.

    Returns:
        str: The name of the created task.
    """
    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(project_id, region, queue_name)

    http_request = {
        "http_method": tasks_v2.HttpMethod.POST,
        "url": task_url,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload_dict).encode('utf-8'),
    }

    if service_account_email:
        http_request["oidc_token"] = {
            "service_account_email": service_account_email,
        }

    task_config = {"http_request": http_request}

    if schedule_time:
        timestamp = timestamp_pb2.Timestamp()
        timestamp.FromDatetime(schedule_time)
        task_config["schedule_time"] = timestamp
    
    response = client.create_task(parent=parent, task=task_config)
    print(f"Created task {response.name} in queue {queue_name} for URL {task_url}.")
    return response.name

def delete_task_by_name(task_name: str) -> None:
    """Deletes a Cloud Task given its full name.

    Args:
        task_name: The full name of the task (e.g., projects/PROJECT_ID/locations/LOCATION_ID/queues/QUEUE_ID/tasks/TASK_ID).
    """
    client = tasks_v2.CloudTasksClient()
    try:
        client.delete_task(name=task_name)
        print(f"Successfully deleted task: {task_name}")
    except google.api_core.exceptions.NotFound:
        print(f"Task {task_name} not found, might have been deleted already.")
    except Exception as e:
        print(f"Error deleting task {task_name}: {e}")