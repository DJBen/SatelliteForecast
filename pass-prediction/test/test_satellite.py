#!/usr/bin/env python3
# Copyright 2025
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

import pytest
from utils.satellite import calculate_satellite_position, find_visible_satellite_transits


def test_calculate_satellite_position():
    # ISS (ZARYA) TLE as of a sample date
    line1 = "1 25544U 98067A   19343.69339541  .00001764  00000-0  38792-4 0  9991"
    line2 = "2 25544  51.6439 211.2001 0007417  17.6667  85.6398 15.50103472202482"
    
    # Example observer location (San Francisco)
    lat = 37.7749
    lon = -122.4194
    
    # Calculate position for a specific time
    time_str = "2019-12-09T20:42:00"
    
    # Test with earth_projection enabled (default)
    result = calculate_satellite_position(line1, line2, time_str)
    
    # Check that result has no errors
    assert result["error"] is None
    
    # Check that position and velocity are returned
    assert "position" in result
    assert "velocity" in result
    assert "earth_projection" in result
    
    # Check that x, y, z components are present
    assert all(key in result["position"] for key in ["x", "y", "z"])
    assert all(key in result["velocity"] for key in ["x", "y", "z"])
    assert all(key in result["earth_projection"] for key in ["longitude", "latitude", "altitude"])
    
    # Check that the time used is correct
    assert result["time"] == time_str

    # Test with earth_projection disabled
    result_no_projection = calculate_satellite_position(line1, line2, time_str, include_earth_projection=False)
    
    # Check that earth_projection is not in the result
    assert "earth_projection" not in result_no_projection

def test_find_visible_satellite_transits():
    """
    Test the find_visible_satellite_transits function for ISS (ZARYA).
    
    This test sets up the function call with:
    - ISS TLE data
    - Observer location
    - Date range around May 20, 2025
    """
    # ISS (ZARYA) TLE as of a sample date
    line1 = "1 25544U 98067A   25140.21045238  .00008546  00000-0  15962-3 0  9996"
    line2 = "2 25544  51.6372  85.6698 0002547 123.7739 203.9910 15.49623238510810"
    
    # Observer location
    observer_lat = 37.35
    observer_lon = -122.03
    observer_alt = 0  # altitude in meters
    
    # Time range (May 20-25, 2025, Pacific Time)
    start_time = "2025-05-20T21:00:00-07:00"
    end_time = "2025-05-25T23:55:00-07:00"
    
    # Call the function
    transits = find_visible_satellite_transits(
        line1, 
        line2, 
        observer_lat, 
        observer_lon, 
        observer_alt,
        start_time_str=start_time,
        end_time_str=end_time
    )
    
    # Print the number of visible transits found
    print(f"Found {len(transits)} visible satellite transits")
    
    # This test currently just verifies the function runs without errors
    # Future enhancements could include specific assertions based on expected results
    assert transits is not None
