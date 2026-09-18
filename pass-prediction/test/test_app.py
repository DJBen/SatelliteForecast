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

import flask
from flask.testing import FlaskClient
import json
from unittest.mock import patch


def test_get_index(app: flask.app.Flask, client: FlaskClient) -> None:
    res = client.get("/")
    assert res.status_code == 200


def test_post_index(app: flask.app.Flask, client: FlaskClient) -> None:
    res = client.post("/")
    assert res.status_code == 405


@patch('app.messaging.send') # Patch the send function in the app module
def test_notify_endpoint_success(mock_fcm_send, app: flask.app.Flask, client: FlaskClient) -> None:
    """Test the /notify endpoint with valid JSON data."""
    notification_payload_data = {"message": "test notification", "priority": "high"}
    request_payload = {
        "push_token": "test_push_token_123",
        "title": "Test Notification Title",
        "body": "Test Notification Body",
        "data": notification_payload_data
    }
    
    # Configure the mock for FCM send
    mock_fcm_send.return_value = "mocked_fcm_response_id"
    
    res = client.post(
        "/notify",
        data=json.dumps(request_payload), # Use the corrected payload
        content_type="application/json"
    )
    
    assert res.status_code == 200
    response_data = json.loads(res.data)
    assert response_data["status"] == "success"
    assert response_data["message"] == "Notification processed and sent" # Verify the success message

    # Assert that the mock FCM send was called correctly
    mock_fcm_send.assert_called_once()
    
    # Check the arguments passed to the mocked send call
    # The first positional argument to messaging.send() is the Message object
    sent_message_args = mock_fcm_send.call_args[0]
    sent_message = sent_message_args[0]

    assert sent_message.token == request_payload["push_token"]
    assert sent_message.notification.title == request_payload["title"]
    assert sent_message.notification.body == request_payload["body"]
    assert sent_message.data == notification_payload_data


def test_notify_endpoint_invalid_json(app: flask.app.Flask, client: FlaskClient) -> None:
    """Test the /notify endpoint with invalid JSON data."""
    res = client.post(
        "/notify",
        data="invalid json",
        content_type="application/json"
    )
    
    assert res.status_code == 500
    response_data = json.loads(res.data)
    assert "error" in response_data


def test_sgp4_endpoint_success(app: flask.app.Flask, client: FlaskClient) -> None:
    """Test the /sgp4 endpoint with valid data."""
    test_data = {
        "line1": "1 25544U 98067A   19343.69339541  .00001764  00000-0  38792-4 0  9991",
        "line2": "2 25544  51.6439 211.2001 0007417  17.6667  85.6398 15.50103472202482",
        "lat": 37.7749,
        "lon": -122.4194
    }
    
    res = client.get(
        "/sgp4",
        json=test_data
    )
    
    assert res.status_code == 200
    response_data = json.loads(res.data)
    assert "position" in response_data
    assert "velocity" in response_data
    assert "time" in response_data
    assert response_data["error"] is None


def test_sgp4_endpoint_with_time(app: flask.app.Flask, client: FlaskClient) -> None:
    """Test the /sgp4 endpoint with valid data including the optional time parameter."""
    test_data = {
        "line1": "1 25544U 98067A   19343.69339541  .00001764  00000-0  38792-4 0  9991",
        "line2": "2 25544  51.6439 211.2001 0007417  17.6667  85.6398 15.50103472202482",
        "lat": 37.7749,
        "lon": -122.4194,
        "time": "2019-12-09T20:42:00"
    }
    
    res = client.get(
        "/sgp4",
        json=test_data
    )
    
    assert res.status_code == 200
    response_data = json.loads(res.data)
    assert response_data["time"] == "2019-12-09T20:42:00"


def test_sgp4_endpoint_missing_parameters(app: flask.app.Flask, client: FlaskClient) -> None:
    """Test the /sgp4 endpoint with missing required parameters."""
    test_data = {
        "line1": "1 25544U 98067A   19343.69339541  .00001764  00000-0  38792-4 0  9991",
        # Missing line2
        "lat": 37.7749,
        "lon": -122.4194
    }
    
    res = client.get(
        "/sgp4",
        json=test_data
    )
    
    assert res.status_code == 400
    response_data = json.loads(res.data)
    assert "error" in response_data

