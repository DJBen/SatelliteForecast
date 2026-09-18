import json
import os
import sys
import requests
from google.cloud import storage

# Retrieve Job-defined env vars
TASK_INDEX = os.getenv("CLOUD_RUN_TASK_INDEX", 0)
TASK_ATTEMPT = os.getenv("CLOUD_RUN_TASK_ATTEMPT", 0)
# Retrieve User-defined env vars
SATELLITE_ID = os.getenv("SATELLITE_ID")
BUCKET_NAME = os.getenv("BUCKET_NAME", "pass-prediction_tle")

def fetch_tle(satellite_id):
    """Fetches TLE data from a dummy URL using the satellite ID."""
    #  Replace with your actual TLE data source URL.
    url = f"https://celestrak.org/NORAD/elements/gp.php?CATNR={satellite_id}&FORMAT=TLE"  
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()  # Raise for bad status codes
        tle_data = response.text
        
        # Validate that TLE data has exactly 3 lines
        lines = [line for line in tle_data.strip().split('\n') if line.strip()]
        if len(lines) != 3:
            raise ValueError(f"Invalid TLE format: Expected 3 lines, got {len(lines)}")
        
        return tle_data
    except requests.exceptions.RequestException as e:
        print(f"Error fetching TLE for satellite {satellite_id} from {url}: {e}")
        return None
    except ValueError as e:
        print(f"Error validating TLE data for satellite {satellite_id}: {e}")
        return None

def upload_to_gcs(bucket_name, file_name, data):
    """Uploads the TLE data to Google Cloud Storage."""
    if not data:
        print(f"No data to upload to GCS bucket {bucket_name}.")
        return False

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    try:
        blob.upload_from_string(data)
        print(f"Successfully uploaded {file_name} to {bucket_name}.")
        return True
    except Exception as e:
        print(f"Error uploading to GCS bucket {bucket_name}: {e}")
        return False

def main(satellite_id, bucket_name):
    """Main function to orchestrate the TLE fetching and uploading."""
    print(f"Starting Task #{TASK_INDEX}, Attempt #{TASK_ATTEMPT}...")
    
    if not satellite_id:
        raise ValueError("SATELLITE_ID environment variable is required")
    
    tle_data = fetch_tle(satellite_id)
    if tle_data:
        file_name = f"tle_{satellite_id}.txt"
        upload_result = upload_to_gcs(bucket_name, file_name, tle_data)
        if not upload_result:
            raise Exception(f"Failed to upload TLE data for satellite {satellite_id}")
    else:
        raise Exception(f"Failed to retrieve TLE data for satellite {satellite_id}")
    
    print(f"Completed Task #{TASK_INDEX}.")

# Start script
if __name__ == "__main__":
    try:
        main(SATELLITE_ID, BUCKET_NAME)
    except Exception as err:
        message = f"Task #{TASK_INDEX}, Attempt #{TASK_ATTEMPT} failed: {str(err)}"
        print(json.dumps({"message": message, "severity": "ERROR"}))
        sys.exit(1)  # Retry Job Task by exiting the process