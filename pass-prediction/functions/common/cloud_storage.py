
from google.cloud import storage
from firebase_functions import logger


def download_tle_file(satellite_id):
    """
    Downloads a TLE file for a specific satellite from Google Cloud Storage.
    
    Args:
        satellite_id (str): The ID of the satellite
        
    Returns:
        tuple: A tuple containing (line1, line2) of the TLE data
        None: If there was an error downloading or parsing the file
    """
    try:
        # Create a storage client
        storage_client = storage.Client()
        
        # Specify the bucket name
        bucket_name = "pass-prediction_tle"
        
        # Specify the file name
        file_name = f"tle_{satellite_id}.txt"
        
        # Get the bucket
        bucket = storage_client.bucket(bucket_name)
        
        # Get the blob (file)
        blob = bucket.blob(file_name)
        
        # Download the content as string
        content = blob.download_as_text()
        
        # Split the content into lines and clean any carriage returns
        lines = [line.strip() for line in content.strip().split('\n')]

        # Check if we have at least 3 lines
        if len(lines) < 3:
            logger.error(f"Invalid TLE file format for satellite {satellite_id}. Insufficient lines.")
            return None
        
        # Return line 2 and 3 (index 1 and 2) as per requirements
        return lines[1], lines[2]
        
    except Exception as e:
        logger.exception(f"Error downloading TLE file for satellite {satellite_id}", error=str(e))
        return None
