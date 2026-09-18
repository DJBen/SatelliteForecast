# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import signal
import sys
from types import FrameType

from flask import Flask, request, jsonify
import json
import datetime
import numpy as np

from utils.logging import logger
from utils.satellite import (
    calculate_satellite_position, 
    calculate_satellite_position_and_observation,
    calculate_satellite_observation_batch,
    find_visible_satellite_transits
)
from utils.cloud_task import schedule_notification, delete_task_by_name
from utils.cloud_storage import download_tle_file
from google.cloud import firestore as google_firestore
import google.auth
import firebase_admin
from firebase_admin import credentials, messaging

app = Flask(__name__)

def shutdown_handler(signal_int: int, frame: FrameType) -> None:
    logger.info(f"Caught Signal {signal.strsignal(signal_int)}")

    from utils.logging import flush

    flush()

    # Safely exit program
    sys.exit(0)

# Initialize Firestore client for Cloud Run
try:
    _, PROJECT_ID_APP = google.auth.default()
    db = google_firestore.Client(project=PROJECT_ID_APP)
    logger.info(f"Firestore client initialized for project {PROJECT_ID_APP} in app.py.")
    # Initialize Firebase Admin SDK
    firebase_admin.initialize_app()
    logger.info("Firebase Admin SDK initialized.")
except Exception as e:
    logger.error(f"Failed to initialize Firestore client or Firebase Admin SDK in app.py: {e}")
    signal.signal(signal.SIGTERM, shutdown_handler)

@app.route("/")
def hello() -> str:
    return "Hello, World!"

@app.route("/notify", methods=["POST"])
def notify():
    try:
        data = request.get_json()
        logger.info("Received notification data", data=data)

        task_name = request.headers.get("X-CloudTasks-TaskName")
        
        required_fields = ["push_token", "title", "body"]
        if not all(field in data for field in required_fields):
            logger.warning("Missing required fields in /notify request", received_data=data)
            return jsonify({"error": "Missing required fields. Need: push_token, title, body"}), 400

        push_token = data["push_token"]
        title = data["title"]
        body = data["body"]
        notification_data = data.get("data", {}) # Optional data payload for the notification

        # Delete the task from Firestore if task_name is present
        if task_name and db:
            try:
                # Extract the actual task ID from the full task name
                # Format: projects/PROJECT_ID/locations/LOCATION_ID/queues/QUEUE_ID/tasks/TASK_ID
                effective_task_id = task_name.split('/')[-1]
                
                doc_ref = db.collection('users').document(push_token).collection('scheduled_notifications').document(effective_task_id)
                doc = doc_ref.get()
                if doc.exists:
                    doc_ref.delete()
                    logger.info(f"Successfully deleted Firestore record for task {effective_task_id} for user {push_token}")
                else:
                    logger.warning(f"Firestore record for task {effective_task_id} not found for user {push_token}. Might have been already processed or deleted.")
            except Exception as e:
                logger.error(f"Error deleting Firestore record for task {task_name} for user {push_token}: {e}")
                # Continue to send notification even if Firestore deletion fails

        # Send FCM notification
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=notification_data, # FCM data payload must be strings
                token=push_token,
            )
            response = messaging.send(message)
            logger.info(f"Successfully sent FCM message to {push_token}: {response}")
        except firebase_admin.exceptions.FirebaseError as e:
            logger.error(f"Error sending FCM message to {push_token}: {e}")
            # Check if the token is unregistered
            if isinstance(e, messaging.UnregisteredError):
                logger.warning(f"Push token {push_token} is unregistered. Consider removing it from the user's profile.")
                # Potentially add logic here to mark the token as invalid in your user database
            return jsonify({"error": f"Failed to send FCM message: {str(e)}"}), 500
        except Exception as e:
            logger.error(f"Unexpected error sending FCM message to {push_token}: {e}")
            return jsonify({"error": f"Unexpected error sending FCM message: {str(e)}"}), 500

        return jsonify({"status": "success", "message": "Notification processed and sent"})
    except Exception as e:
        logger.exception("Error in /notify endpoint", error=str(e))
        return jsonify({"error": f"Error processing request: {str(e)}"}), 500

@app.route("/schedule", methods=["POST"])
def schedule_task():
    try:
        data = request.get_json()
        
        # Validate required parameters
        if not all(key in data for key in ["payload"]):
            return jsonify({
                "error": "Missing required parameters. Need 'payload' at minimum."
            }), 400
            
        # Get the payload to be sent later
        payload = json.dumps(data["payload"])
                
        # Parse schedule_time if provided
        schedule_time = None
        if "schedule_time" in data and data["schedule_time"]:
            try:
                schedule_time = datetime.datetime.fromisoformat(data["schedule_time"])
            except ValueError:
                return jsonify({
                    "error": "Invalid schedule_time format. Use ISO format (YYYY-MM-DDTHH:MM:SS)."
                }), 400
                
        # Create the cloud task
        task_name = schedule_notification(payload, schedule_time)
        
        return jsonify({
            "status": "success", 
            "message": "Task scheduled successfully",
            "task_name": task_name
        })
        
    except Exception as e:
        logger.exception("Error in schedule_task endpoint", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/sgp4", methods=["GET"])
def sgp4_endpoint():
    try:
        data = request.get_json()

        # Validate required parameters
        if not all(key in data for key in ["line1", "line2"]):
            return jsonify({
                "error": "Missing required parameters. Need 'line1', 'line2'."
            }), 400

        # Extract parameters
        line1 = data["line1"]
        line2 = data["line2"]
        time_str = data.get("time")  # Optional parameter
        
        # Get earth_projection parameter, default to True
        include_earth_projection = data.get("include_earth_projection", True)
        
        # Convert string to boolean if needed
        if isinstance(include_earth_projection, str):
            include_earth_projection = include_earth_projection.lower() == 'true'

        # Calculate satellite position
        result = calculate_satellite_position(line1, line2, time_str, include_earth_projection)

        # Check for errors
        if result["error"]:
            return jsonify({"error": result["error"]}), 400

        return jsonify(result)

    except Exception as e:
        logger.exception("Error in sgp4 endpoint", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/sgp4/<satellite_id>", methods=["GET"])
def sgp4_by_satellite_id(satellite_id):
    try:
        # Get optional time parameter from query string
        time_str = request.args.get("time")
        
        # Get earth_projection parameter, default to True
        include_earth_projection = request.args.get("include_earth_projection", "true").lower() == "true"
        
        # Get TLE data from Cloud Storage
        tle_result = download_tle_file(satellite_id)
        
        # Check if TLE data retrieval was successful
        if tle_result is None:
            return jsonify({
                "error": f"Failed to retrieve TLE data for satellite ID: {satellite_id}"
            }), 404
            
        # Unpack the TLE data
        line1, line2 = tle_result
        
        # Calculate satellite position using the retrieved TLE data
        result = calculate_satellite_position(line1, line2, time_str, include_earth_projection)
        
        # Check for errors in calculation
        if result["error"]:
            return jsonify({"error": result["error"]}), 400
            
        # Add satellite ID to the result
        result["satellite_id"] = satellite_id
        
        return jsonify(result)
        
    except Exception as e:
        logger.exception(f"Error in sgp4 endpoint for satellite {satellite_id}", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/observe-satellite/<satellite_id>", methods=["GET"])
def observe_satellite(satellite_id):
    try:
        # Validate required query parameters
        required_params = ["observer_lat", "observer_lon"]
        missing_params = [param for param in required_params if param not in request.args]
        
        if missing_params:
            return jsonify({
                "error": f"Missing required parameters: {', '.join(missing_params)}"
            }), 400
            
        # Extract and convert parameters
        try:
            observer_lat = float(request.args.get("observer_lat"))
            observer_lon = float(request.args.get("observer_lon"))
            observer_alt = float(request.args.get("observer_alt", 0))  # Optional, default 0
        except ValueError:
            return jsonify({
                "error": "Invalid parameter values. Latitude, longitude, and altitude must be numeric."
            }), 400
            
        # Get optional time parameter
        time_str = request.args.get("time")
        
        # Get earth_projection parameter, default to True
        include_earth_projection = request.args.get("include_earth_projection", "true").lower() == "true"
        
        # Get TLE data from Cloud Storage
        tle_result = download_tle_file(satellite_id)
        
        # Check if TLE data retrieval was successful
        if tle_result is None:
            return jsonify({
                "error": f"Failed to retrieve TLE data for satellite ID: {satellite_id}"
            }), 404
            
        # Unpack the TLE data
        line1, line2 = tle_result
        
        # Calculate satellite position, velocity, and observation data
        result = calculate_satellite_position_and_observation(
            line1, line2, observer_lat, observer_lon, observer_alt, time_str, include_earth_projection
        )
        
        # Check for errors in calculation
        if result["error"]:
            return jsonify({"error": result["error"]}), 400
            
        # Add satellite ID to the result
        result["satellite_id"] = satellite_id
        
        # If observation data is still null but we don't have an error, add a warning
        if result["observation"] is None:
            result["warning"] = "Observation data could not be calculated"
        elif all(result["observation"][key] is None for key in result["observation"]):
            result["warning"] = "Observation data returned null values"
        
        return jsonify(result)
        
    except Exception as e:
        logger.exception(f"Error in observe_satellite endpoint for satellite {satellite_id}", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/tle/<satellite_id>", methods=["GET"])
def get_tle(satellite_id):
    try:
        # Call the utility function to download and parse the TLE file
        result = download_tle_file(satellite_id)
        
        # Check if result is None (error occurred)
        if result is None:
            return jsonify({
                "error": f"Failed to retrieve TLE data for satellite ID: {satellite_id}"
            }), 404
        
        # Unpack the result
        line1, line2 = result
        
        # Return the TLE data
        return jsonify({
            "satellite_id": satellite_id,
            "line1": line1,
            "line2": line2
        })
        
    except Exception as e:
        logger.exception(f"Error retrieving TLE for satellite {satellite_id}", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/observe-satellite-batch/<satellite_id>", methods=["GET"])
def observe_satellite_batch(satellite_id):
    try:
        # Validate required query parameters
        required_params = ["observer_lat", "observer_lon"]
        missing_params = [param for param in required_params if param not in request.args]
        
        if missing_params:
            return jsonify({
                "error": f"Missing required parameters: {', '.join(missing_params)}"
            }), 400
            
        # Extract and convert observer parameters
        try:
            observer_lat = float(request.args.get("observer_lat"))
            observer_lon = float(request.args.get("observer_lon"))
            observer_alt = float(request.args.get("observer_alt", 0))  # Optional, default 0
        except ValueError:
            return jsonify({
                "error": "Invalid parameter values. Latitude, longitude, and altitude must be numeric."
            }), 400
        
        # Extract and convert time range parameters
        start_time_str = request.args.get("start_time")  # Optional
        end_time_str = request.args.get("end_time")      # Optional
        include_position_and_velocity = request.args.get("include_position_and_velocity", "false").lower() == "true"
        includes_elevation_velocity = request.args.get("includes_elevation_velocity", "false").lower() == "true"
        
        try:
            # Allow both integer and float values
            interval_sec = float(request.args.get("interval_sec", 60))
        except ValueError:
            return jsonify({
            "error": "Invalid parameter values. interval_sec must be numeric."
            }), 400
            
        # Get TLE data from Cloud Storage
        tle_result = download_tle_file(satellite_id)
        
        # Check if TLE data retrieval was successful
        if tle_result is None:
            return jsonify({
                "error": f"Failed to retrieve TLE data for satellite ID: {satellite_id}"
            }), 404
            
        # Unpack the TLE data
        line1, line2 = tle_result
        
        # Calculate satellite positions, velocities, and observations in batch
        batch_result = calculate_satellite_observation_batch(
            line1, line2, 
            observer_lat, observer_lon, observer_alt, 
            start_time_str, end_time_str, interval_sec,
            include_position_and_velocity,
            includes_elevation_velocity
        )
        
        # Check if there's an error
        if isinstance(batch_result, dict) and "error" in batch_result:
            return jsonify(batch_result), 400
        
        # Unpack the vectors from the tuple
        (
            jds, frs, 
            azimuths, elevations, ranges, 
            is_illuminated, sun_elevations, 
            elevation_velocity, 
            r, v
        ) = batch_result
        
        # Construct the result dictionaries
        results = []
        for i in range(len(jds)):
            result_dict = {
                "observation": {
                    "azimuth": float(azimuths[i]),
                    "elevation": float(elevations[i]),
                    "range": float(ranges[i]),  # in km
                    "is_illuminated": bool(is_illuminated[i]),
                    "sun_elevation": float(sun_elevations[i])  # Sun elevation in degrees
                },
                "jd": float(jds[i]),
                "fr": float(frs[i])
            }
            
            # Add elevation velocity if available
            if includes_elevation_velocity and elevation_velocity is not None:
                result_dict["observation"]["elevation_velocity"] = float(elevation_velocity[i])
            
            # Only include position and velocity if requested and available
            if include_position_and_velocity and r is not None and v is not None:
                result_dict["position"] = {
                    "x": float(r[0, i, 0]),
                    "y": float(r[0, i, 1]),
                    "z": float(r[0, i, 2])
                }
                result_dict["velocity"] = {
                    "x": float(v[0, i, 0]),
                    "y": float(v[0, i, 1]),
                    "z": float(v[0, i, 2])
                }
            
            results.append(result_dict)
                
        # Return results with additional metadata
        response = {
            "satellite_id": satellite_id,
            "request_metadata": {
                "observer_lat": observer_lat,
                "observer_lon": observer_lon,
                "observer_alt": observer_alt,
                "start_time": start_time_str,
                "end_time": end_time_str,
                "interval_sec": interval_sec,
                "include_position_and_velocity": include_position_and_velocity,
                "includes_elevation_velocity": includes_elevation_velocity,
                "result_count": len(results)
            },
            "results": results
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.exception(f"Error in observe_satellite_batch endpoint for satellite {satellite_id}", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500
    
@app.route("/compute_and_schedule", methods=["POST"])
def compute_and_schedule_pass_notifications():
    if db is None:
        logger.error("Firestore client is not available in /compute_and_schedule.")
        return jsonify({"error": "Internal server error: Firestore not configured"}), 500
    try:
        data = request.get_json()
        logger.info("Received compute_and_schedule request", data=data)

        required_fields = ["push_token", "lat", "lon", "alt", "satellite_ids"]
        if not all(field in data for field in required_fields):
            logger.warning("Missing required fields in /compute_and_schedule request", received_data=data)
            return jsonify({"error": "Missing required fields. Need: " + ", ".join(required_fields)}), 400

        push_token = data["push_token"]
        try:
            observer_lat = float(data["lat"])
            observer_lon = float(data["lon"])
            observer_alt = float(data["alt"])
        except ValueError as ve:
            logger.warning(f"Invalid location data for /compute_and_schedule: {ve}", received_data=data)
            return jsonify({"error": f"Invalid location data (lat, lon, alt must be numbers): {str(ve)}"}), 400
            
        satellite_ids = data["satellite_ids"]

        if not isinstance(satellite_ids, list):
            logger.warning("satellite_ids is not a list in /compute_and_schedule", received_data=data)
            return jsonify({"error": "satellite_ids must be a list"}), 400
        
        # --- Cancel old notification tasks ---
        final_notifications_ref = db.collection('users').document(push_token).collection('scheduled_notifications')
        
        tasks_to_delete_firestore_refs = []
        for task_doc in final_notifications_ref.stream():
            task_name_to_delete = task_doc.id
            logger.info(f"Found old final notification task to cancel: {task_name_to_delete} for user {push_token}")
            try:
                delete_task_by_name(task_name_to_delete)
                logger.info(f"Successfully deleted task {task_name_to_delete} from Cloud Tasks.")
            except Exception as e: 
                logger.error(f"Error deleting task {task_name_to_delete} from Cloud Tasks: {e}. It will be removed from Firestore anyway.")
            tasks_to_delete_firestore_refs.append(task_doc.reference)

        if tasks_to_delete_firestore_refs:
            batch = db.batch()
            for doc_ref in tasks_to_delete_firestore_refs:
                batch.delete(doc_ref)
            batch.commit()
            logger.info(f"Cleaned up {len(tasks_to_delete_firestore_refs)} old final notification task entries from Firestore for user {push_token}.")

        # --- Compute satellite passes ---
        all_passes_for_user = []
        start_time_dt = datetime.datetime.now(datetime.timezone.utc)
        end_time_dt = start_time_dt + datetime.timedelta(days=3) 
        start_time_str = start_time_dt.isoformat()
        end_time_str = end_time_dt.isoformat()

        for sat_id_input in satellite_ids:
            sat_id = str(sat_id_input) # Ensure it's a string
            logger.info(f"Processing satellite ID: {sat_id} for user {push_token}")
            tle_result = download_tle_file(sat_id)
            if tle_result is None:
                logger.warning(f"Could not retrieve TLE for satellite {sat_id}. Skipping.")
                continue
            line1, line2 = tle_result

            transits = find_visible_satellite_transits(
                line1, line2,
                observer_lat, observer_lon, observer_alt,
                start_time_str=start_time_str,
                end_time_str=end_time_str,
            )

            if isinstance(transits, dict) and "error" in transits:
                logger.error(f"Error finding transits for {sat_id}: {transits['error']}. Skipping.")
                continue
            
            logger.info(f"Found {len(transits)} transits for satellite {sat_id}")
            for transit in transits:
                # A transit is included if visible_above_10_deg_duration_sec > 0.
                # This implies culmination, elev10_rise, and elev10_set should exist.
                if (transit.get("visible_above_10_deg_duration_sec", 0) > 0 and
                    transit.get("culmination") and transit.get("culmination", {}).get("time") and
                    transit.get("elev10_rise") and transit.get("elev10_rise", {}).get("time") and
                    transit.get("elev10_set") and transit.get("elev10_set", {}).get("time")):
                    
                    processed_transit = {
                        'satellite_id': sat_id,
                        'transit': transit,
                        'peak_time_utc': transit['culmination']['time'],
                        'max_elevation_deg': transit.get('visible_culmination_elev', transit['culmination']['obs']['elevation']),
                        'aos_time_utc': transit['elev10_rise']['time'],
                        'los_time_utc': transit['elev10_set']['time'],
                        'visible_duration_sec': transit['visible_above_10_deg_duration_sec']
                    }
                    all_passes_for_user.append(processed_transit)
                else:
                    logger.info(f"Skipping incomplete or non-visible transit for {sat_id}: {transit.get('culmination', {}).get('time')}")

        # --- Schedule new final notification tasks ---
        scheduled_notification_count = 0
        for a_pass in all_passes_for_user: # Now a_pass is one of our processed_transit dicts
            try:
                peak_time_utc_str = a_pass['peak_time_utc']
                # Ensure 'Z' is handled correctly for ISO format parsing
                if peak_time_utc_str.endswith('Z'):
                    peak_time_utc_str = peak_time_utc_str[:-1] + '+00:00'
                peak_time_utc_dt = datetime.datetime.fromisoformat(peak_time_utc_str)
                
                notification_time_dt = peak_time_utc_dt - datetime.timedelta(minutes=15)

                if notification_time_dt <= datetime.datetime.now(datetime.timezone.utc):
                    logger.info(f"Skipping past notification for sat {a_pass['satellite_id']} at {peak_time_utc_dt} for user {push_token}")
                    continue

                satellite_display_name = a_pass.get('satellite_name', a_pass['satellite_id'])

                notification_payload_dict = {
                    "push_token": push_token,
                    "title": f"Satellite Pass: {satellite_display_name}",
                    "body": f"Visible around {peak_time_utc_dt.strftime('%H:%M %Z')} (peak: {a_pass['max_elevation_deg']:.0f}°). Tap for details.",
                    "data": {
                        "satellite_id": a_pass['satellite_id'],
                        "transit": a_pass['transit'],
                        "peak_time_utc": a_pass['peak_time_utc'],
                        "max_elevation_deg": a_pass['max_elevation_deg'],
                        "aos_time_utc": a_pass['aos_time_utc'],
                        "los_time_utc": a_pass['los_time_utc'],
                        "visible_duration_sec": a_pass.get('visible_duration_sec')
                    }
                }
                
                created_task_name = schedule_notification(
                    payload=json.dumps(notification_payload_dict), 
                    schedule_time=notification_time_dt
                )
                logger.info(f"Scheduled notification task {created_task_name} for pass of {a_pass['satellite_id']} at {notification_time_dt} for user {push_token}")

                new_final_task_doc_ref = final_notifications_ref.document(created_task_name)
                new_final_task_doc_ref.set({
                    "created_at": google_firestore.SERVER_TIMESTAMP,
                    "satellite_id": a_pass['satellite_id'],
                    "pass_peak_time_utc": a_pass['peak_time_utc'], # This is correct now
                    "pass_max_elevation_deg": a_pass['max_elevation_deg'],
                    "pass_aos_utc": a_pass['aos_time_utc'],
                    "pass_los_utc": a_pass['los_time_utc'],
                    "notification_scheduled_at_utc": notification_time_dt.isoformat(),
                    "notification_title": notification_payload_dict["title"]
                })
                scheduled_notification_count += 1
            except Exception as e:
                logger.error(f"Error scheduling notification for pass {a_pass.get('peak_time_utc')} of sat {a_pass.get('satellite_id')} for user {push_token}: {e}")
        
        logger.info(f"Successfully processed /compute_and_schedule for {push_token}. Found {len(all_passes_for_user)} passes, scheduled {scheduled_notification_count} notifications.")
        return jsonify({
            "status": "success", 
            "message": f"Processed passes. Found {len(all_passes_for_user)} potential passes. Scheduled {scheduled_notification_count} notifications.",
            "push_token": push_token
        }), 200

    except ValueError as ve:
        logger.error(f"Value error in /compute_and_schedule: {ve}", exc_info=True)
        return jsonify({"error": f"Invalid input data: {str(ve)}"}), 400
    except Exception as e:
        logger.exception("Critical error in /compute_and_schedule endpoint", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/find-transits/<satellite_id>", methods=["GET"])
def find_transits(satellite_id):
    try:
        # Validate required query parameters
        required_params = ["observer_lat", "observer_lon"]
        missing_params = [param for param in required_params if param not in request.args]
        
        if missing_params:
            return jsonify({
                "error": f"Missing required parameters: {', '.join(missing_params)}"
            }), 400
            
        # Extract and convert parameters
        try:
            observer_lat = float(request.args.get("observer_lat"))
            observer_lon = float(request.args.get("observer_lon"))
            observer_alt = float(request.args.get("observer_alt", 0))  # Optional, default 0
        except ValueError:
            return jsonify({
                "error": "Invalid parameter values. Latitude, longitude, and altitude must be numeric."
            }), 400
            
        # Extract optional parameters
        start_time_str = request.args.get("start_time")
        end_time_str = request.args.get("end_time")
        
        try:
            max_sun_elevation = float(request.args.get("max_sun_elevation", -4.0))
        except ValueError:
            return jsonify({
                "error": "Invalid max_sun_elevation value. Must be numeric."
            }), 400
        
        # Get TLE data from Cloud Storage
        tle_result = download_tle_file(satellite_id)
        
        # Check if TLE data retrieval was successful
        if tle_result is None:
            return jsonify({
                "error": f"Failed to retrieve TLE data for satellite ID: {satellite_id}"
            }), 404
            
        # Unpack the TLE data
        line1, line2 = tle_result
        
        # Find visible satellite transits
        
        transits = find_visible_satellite_transits(
            line1, line2, 
            observer_lat, observer_lon, observer_alt,
            start_time_str, end_time_str, 
            max_sun_elevation
        )
        
        # Check for errors
        if isinstance(transits, dict) and "error" in transits:
            return jsonify(transits), 400
        
        # Return the transit data
        return jsonify({
            "satellite_id": satellite_id,
            "request_parameters": {
                "observer_lat": observer_lat,
                "observer_lon": observer_lon,
                "observer_alt": observer_alt,
                "start_time": start_time_str,
                "end_time": end_time_str,
                "max_sun_elevation": max_sun_elevation
            },
            "transits": transits,
            "transit_count": len(transits)
        })
        
    except Exception as e:
        logger.exception("Error in find_transits endpoint", error=str(e))
        return jsonify({"error": f"Server error: {str(e)}"}), 500

if __name__ == "__main__":
    # Running application locally, outside of a Google Cloud Environment

    # handles Ctrl-C termination
    signal.signal(signal.SIGINT, shutdown_handler)

    app.run(host="localhost", port=8080, debug=True)
else:
    # handles Cloud Run container termination
    signal.signal(signal.SIGTERM, shutdown_handler)
