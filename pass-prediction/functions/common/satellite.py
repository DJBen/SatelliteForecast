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

from datetime import datetime, UTC, timedelta
import numpy as np
from sgp4.api import Satrec, SatrecArray, SGP4_ERRORS, jday, accelerated
import astropy.units as u
from astropy.coordinates import EarthLocation, SkyCoord, AltAz, GCRS, get_sun
from astropy.time import Time
from firebase_functions import logger
import time as timing

def calculate_satellite_observation_batch(line1, line2, observer_lat, observer_lon, observer_alt=0, start_time_str=None, end_time_str=None, scan_interval_sec=60, includes_position_and_velocity=False, includes_elevation_velocity=False):
    """
    Calculate satellite observation parameters (azimuth, elevation, range) and sun illumination
    from a ground observer's position, given the satellite's position and velocity in ECI frame.
    This function scans over a specified time period and returns a list of observations.
    The function generates a sequence of Julian dates over the specified time period
    with regular time intervals, and for each time step, it calculates the satellite's position
    and observation parameters.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float, optional): Observer's altitude in meters. Default is 0.
        start_time_str (str, optional): Start time_str in iso format for scanning. If None, current date is used.
        end_time_str (str, optional): End time_str in iso format for scanning. If None, start_time + 7 days is used.
        scan_interval_sec (int, optional): Interval in seconds for scanning. Default is 60.
        includes_position_and_velocity (bool, optional): Whether to include position and velocity in the result.
        includes_elevation_velocity (bool, optional): Whether to include apparent elevation velocity (deg/s) in the result.
    
    Returns:
        tuple or dict: If successful, returns a tuple of raw vectors (see calculate_satellite_observation_batch_jd).
                      If an error occurs, returns a dict with error information.
    """

    if start_time_str is None:
        # Use current time as start_time if not provided
        start_time_str = datetime.now(UTC).isoformat()
        
    if end_time_str is None:
        # Default to 7 days from start if not specified
        start_dt, _ = _parse_time_to_utc(start_time_str)
        end_dt = start_dt + timedelta(days=7)
        end_time_str = end_dt.isoformat()

    try:
        # Convert start time to Julian date
        start_dt, _ = _parse_time_to_utc(start_time_str)
        year, month, day = start_dt.year, start_dt.month, start_dt.day
        hour, minute, second = start_dt.hour, start_dt.minute, start_dt.second + start_dt.microsecond / 1_000_000
        start_jd, start_fr = jday(year, month, day, hour, minute, second)
        
        # Convert end time to Julian date
        if end_time_str:
            end_dt, _ = _parse_time_to_utc(end_time_str)
        else:
            # Default to 7 days from start if not specified
            end_dt = start_dt + timedelta(days=7)
        
        year, month, day = end_dt.year, end_dt.month, end_dt.day
        hour, minute, second = end_dt.hour, end_dt.minute, end_dt.second + end_dt.microsecond / 1_000_000
        end_jd, end_fr = jday(year, month, day, hour, minute, second)
        
        # Call the Julian date version of the function
        return calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd, start_fr, end_jd, end_fr, scan_interval_sec, 
            includes_position_and_velocity, includes_elevation_velocity
        )
    
    except Exception as e:
        # Get initial Julian date and return error
        dt, _ = _parse_time_to_utc(start_time_str)
        year, month, day = dt.year, dt.month, dt.day
        hour, minute, second = dt.hour, dt.minute, dt.second + dt.microsecond / 1_000_000
        jd, fr = jday(year, month, day, hour, minute, second)
        
        return {
            "error": f"Batch calculation error: {str(e)}",
            "jd": jd,
            "fr": fr
        }

def find_visible_satellite_transits(
    line1, line2, observer_lat, observer_lon, observer_alt=0, 
    start_time_str=None, end_time_str=None, max_sun_elevation=-4.0
):
    """
    Find satellite transits for a given observer location and time range.
    It efficiently calculates visible satellite transits based on the following criteria:
    - The satellite must be above 10 degrees elevation.
    - The Sun must be below the horizon (elevation < max_sun_elevation degrees) during some part of the transit above 10 degrees.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float, optional): Observer's altitude in meters. Default is 0.
        start_time_str (str, optional): Start time_str in iso format for scanning. If None, current date is used.
        end_time_str (str, optional): End time_str in iso format for scanning. If None, start_time + 7 days is used.
        max_sun_elevation (float, optional): Maximum sun elevation angle for the observer for the transit to be considered potentially visible. Default is -4.0 degrees.
    
    Returns:
        list: List of dictionaries, where each dictionary represents a visible transit and contains:
            - "elev10_rise" (dict, optional): Information about the satellite reaching 10 degrees elevation on ascent.
                - "jd" (float): Julian date + fraction of day.
                - "time" (str): ISO formatted time string.
                - "obs" (dict): Observation data (azimuth, elevation, range, is_illuminated, sun_elevation).
            - "elev10_set" (dict, optional): Information about the satellite reaching 10 degrees elevation on descent.
                - "jd" (float): Julian date + fraction of day.
                - "time" (str): ISO formatted time string.
                - "obs" (dict): Observation data.
            - "culmination" (dict, optional): Information about the satellite's highest point during the pass (between 10-degree rise and set).
                - "jd" (float): Julian date + fraction of day.
                - "time" (str): ISO formatted time string.
                - "obs" (dict): Observation data.
            - "enters_shadow" (dict, optional): Information about when the satellite enters Earth's shadow during the pass.
                - "jd" (float): Julian date + fraction of day.
                - "time" (str): ISO formatted time string.
                - "obs" (dict): Observation data.
            - "leaves_shadow" (dict, optional): Information about when the satellite leaves Earth's shadow during the pass.
                - "jd" (float): Julian date + fraction of day.
                - "time" (str): ISO formatted time string.
                - "obs" (dict): Observation data.
            - "visible_above_10_deg_duration_sec" (float): Duration in seconds the satellite is illuminated and above 10 degrees elevation.
            - "visible_culmination_elev" (float): Highest elevation in degrees achieved by the satellite while illuminated and above 10 degrees.
            A transit is included if `visible_above_10_deg_duration_sec` > 0.
    Note:
        1. The function first performs a coarse scan to identify potential transits where elevation crosses 10 degrees.
        2. For each potential transit, it refines the exact times for 10-degree elevation rise and set using the Newton-Raphson method.
        3. It checks if the Sun's elevation is below `max_sun_elevation` at any point during the 10-degree transit.
        4. If the transit is potentially visible (Sun condition met), it calculates:
           - The culmination point (maximum elevation) between the 10-degree rise and set times.
           - Shadow entry and exit points during this period.
        5. Finally, it computes the `visible_above_10_deg_duration_sec` and `visible_culmination_elev` to determine if the transit is practically observable.
    """
    # Prepare time range for scanning
    if start_time_str is None:
        # Use current time as start_time if not provided
        start_time_str = datetime.now(UTC).isoformat()
        
    if end_time_str is None:
        # Default to 7 days from start if not specified
        start_dt, _ = _parse_time_to_utc(start_time_str)
        end_dt = start_dt + timedelta(days=7)
        end_time_str = end_dt.isoformat()

    # Create a hash of all parameters to use as span_id
    hash_input = f"{line1}{line2}{observer_lat}{observer_lon}{observer_alt}{start_time_str}{end_time_str}{max_sun_elevation}"
     # Generate 16-character hex spanId
     # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#FIELDS.span_id
    span_id = f"{hash(hash_input) & 0xFFFFFFFFFFFFFFFF:016x}" 

    start_time = timing.time()

    # Convert start time to Julian date
    start_dt, _ = _parse_time_to_utc(start_time_str)
    year, month, day = start_dt.year, start_dt.month, start_dt.day
    hour, minute, second = start_dt.hour, start_dt.minute, start_dt.second + start_dt.microsecond / 1_000_000
    start_jd, start_fr = jday(year, month, day, hour, minute, second)
    
    # Convert end time to Julian date
    end_dt, _ = _parse_time_to_utc(end_time_str)
    year, month, day = end_dt.year, end_dt.month, end_dt.day
    hour, minute, second = end_dt.hour, end_dt.minute, end_dt.second + end_dt.microsecond / 1_000_000
    end_jd, end_fr = jday(year, month, day, hour, minute, second)
    
    logger.debug(f"Time range: {start_time_str} to {end_time_str} (JD: {start_jd}+{start_fr:.6f} to {end_jd}+{end_fr:.6f})", spanId=span_id)
    
    # First, perform a coarse scan to find possible transits
    # We'll use 5-minute intervals for the initial scan
    coarse_interval_sec = 300  # 5 minutes
    
    # Get observations for the entire time range with coarse sampling
    coarse_scan_start = timing.time()
    obs_result = calculate_satellite_observation_batch_jd(
        line1, line2, observer_lat, observer_lon, observer_alt,
        start_jd=start_jd, start_fr=start_fr, end_jd=end_jd, end_fr=end_fr,
        scan_interval_sec=coarse_interval_sec, includes_elevation_velocity=True,
        includes_illumination=False, includes_sun_elevation=False
    )
    coarse_scan_end = timing.time()
    logger.debug(f"Coarse scan completed in {coarse_scan_end - coarse_scan_start:.3f}s", spanId=span_id)
    
    # Check if we got a valid result
    if isinstance(obs_result, dict) and "error" in obs_result:
        logger.debug(f"Error in coarse scan: {obs_result['error']}", spanId=span_id)
        return obs_result
    
    # Extract parameters
    jds, frs, _, elevations, _, _, _, _, _, _ = obs_result
    
    # Find potential transit start/end points where elevation crosses the horizon
    # Horizon crossings occur when elevation sign changes
    # Subtract 10 degrees from all elevations to find crossings above 10-degree horizon
    elevation_signs = np.sign(elevations - 10.0)
    elevation_sign_changes = np.where(np.diff(elevation_signs))[0]
    
    logger.debug(f"Found {len(elevation_sign_changes)//2} potential transits", spanId=span_id)
    
    # Initialize list to store transit information
    transit_list = []
    
    # Process each potential transit
    transit_list = []
    total_rise_time = 0
    total_set_time = 0
    total_culm_time = 0
    total_shadow_time = 0
    total_sun_check_time = 0
    
    # Process each potential transit
    for i in range(0, len(elevation_sign_changes), 2):
        # We need pairs of sign changes (rise and set)
        if i + 1 >= len(elevation_sign_changes):
            break
            
        # Get indices of rise and set
        rise_idx = elevation_sign_changes[i]
        set_idx = elevation_sign_changes[i + 1]

        # Ensure we have valid indices
        if set_idx + 1 >= len(elevations):
            continue

        # Verify this is actually a rise/set pair
        # Rise should be negative to positive transition, set should be positive to negative
        if not (elevation_signs[rise_idx] <= 0 and elevation_signs[rise_idx + 1] > 0 and
                elevation_signs[set_idx] > 0 and elevation_signs[set_idx + 1] <= 0):
            continue
        
        # Get approximate times of rise and set
        approx_rise_jd, approx_rise_fr = jds[rise_idx], frs[rise_idx]
        approx_set_jd, approx_set_fr = jds[set_idx + 1], frs[set_idx + 1]
            
        # Calculate 10 degree elevation points (rising and setting)
        # For rising pass
        elev10_rise_start = timing.time()
        elev10_rise_jd, elev10_rise_fr, elev10_rise_obs, elev10_rise_error = _newton_raphson_solve_for_elevation(
            line1, line2, observer_lat, observer_lon, observer_alt,
            approx_rise_jd, approx_rise_fr, target_elevation=10.0, direction='rising'
        )
        total_rise_time += (timing.time() - elev10_rise_start)
        
        if elev10_rise_error is not None:
            logger.debug(f"Error in rising pass: {elev10_rise_error}", spanId=span_id)
            continue

        # For setting pass
        elev10_set_start = timing.time()
        elev10_set_jd, elev10_set_fr, elev10_set_obs, elev10_set_error = _newton_raphson_solve_for_elevation(
            line1, line2, observer_lat, observer_lon, observer_alt,
            approx_set_jd, approx_set_fr, target_elevation=10.0, direction='setting'
        )
        total_set_time += (timing.time() - elev10_set_start)
        
        if elev10_set_error is not None:
            logger.debug(f"Error in setting pass: {elev10_set_error}", spanId=span_id)
            continue

        # Check if this pass might be visible (sun is below max_sun_elevation)
        sun_check_start = timing.time()
        transit_jds, transit_frs = _stride_time_between_jd(
            elev10_rise_jd, elev10_rise_fr, elev10_set_jd, elev10_set_fr, 60  # 1-minute intervals for sun check
        )
        
        transit_obs = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=transit_jds[0], start_fr=transit_frs[0],
            end_jd=transit_jds[-1], end_fr=transit_frs[-1],
            scan_interval_sec=60, includes_illumination=False, includes_sun_elevation=True
        )
        total_sun_check_time += (timing.time() - sun_check_start)
        
        if isinstance(transit_obs, dict) and "error" in transit_obs:
            return transit_obs
            
        _, _, _, _, _, _, transit_sun_elevations, _, _, _ = transit_obs
        
        # Check if at any point during the transit, the sun is below max_sun_elevation
        is_visible = np.any(transit_sun_elevations < max_sun_elevation)
        if not is_visible:
            continue  # Skip this transit if sun never goes below threshold
        
        # Find culmination (maximum elevation) point
        culm_start = timing.time()
        culm_jd, culm_fr, culm_obs = _find_culmination_point(
            line1, line2, observer_lat, observer_lon, observer_alt,
            elev10_rise_jd, elev10_rise_fr, elev10_set_jd, elev10_set_fr
        )
        total_culm_time += (timing.time() - culm_start)
        
        # Find shadow transition points
        shadow_start = timing.time()
        enters_shadow, leaves_shadow = _find_shadow_transition_points(
            line1, line2, observer_lat, observer_lon, observer_alt,
            elev10_rise_jd, elev10_rise_fr, elev10_set_jd, elev10_set_fr
        )
        total_shadow_time += (timing.time() - shadow_start)
        
        # Create transit info dictionary
        transit_info = {}
        
        # Add 10-degree elevation points if found
        if elev10_rise_jd is not None and elev10_rise_error is None:
            elev10_rise_time = Time(elev10_rise_jd + elev10_rise_fr, format='jd').isot
            transit_info["elev10_rise"] = {"jd": elev10_rise_jd + elev10_rise_fr, "time": elev10_rise_time, "obs": elev10_rise_obs}
            
        if elev10_set_jd is not None and elev10_set_error is None:
            elev10_set_time = Time(elev10_set_jd + elev10_set_fr, format='jd').isot
            transit_info["elev10_set"] = {"jd": elev10_set_jd + elev10_set_fr, "time": elev10_set_time, "obs": elev10_set_obs}
        
        # Add culmination if found
        if culm_jd is not None:
            culm_time = Time(culm_jd + culm_fr, format='jd').isot
            transit_info["culmination"] = {"jd": culm_jd + culm_fr, "time": culm_time, "obs": culm_obs}
            
        # Add shadow transitions if found
        if enters_shadow is not None:
            # If enters_shadow is a tuple, convert to dict
            if isinstance(enters_shadow, tuple) and len(enters_shadow) == 3:
                enters_shadow_jd, enters_shadow_fr, enters_shadow_obs = enters_shadow
                enters_shadow_time = Time(enters_shadow_jd + enters_shadow_fr, format='jd').isot
                transit_info["enters_shadow"] = {"jd": enters_shadow_jd + enters_shadow_fr, "time": enters_shadow_time, "obs": enters_shadow_obs}
            else:
                transit_info["enters_shadow"] = enters_shadow
        
        if leaves_shadow is not None:
            # If leaves_shadow is a tuple, convert to dict
            if isinstance(leaves_shadow, tuple) and len(leaves_shadow) == 3:
                leaves_shadow_jd, leaves_shadow_fr, leaves_shadow_obs = leaves_shadow
                leaves_shadow_time = Time(leaves_shadow_jd + leaves_shadow_fr, format='jd').isot
                transit_info["leaves_shadow"] = {"jd": leaves_shadow_jd + leaves_shadow_fr, "time": leaves_shadow_time, "obs": leaves_shadow_obs}
            else:
                transit_info["leaves_shadow"] = leaves_shadow

        # Calculate visible_above_10_deg_duration_sec
        visible_duration = -1
        if "elev10_rise" in transit_info and "elev10_set" in transit_info:
            # Get start and end times for visible duration
            start_jd = transit_info["elev10_rise"]["jd"]
            end_jd = transit_info["elev10_set"]["jd"]
            
            # If satellite enters shadow during pass, use that as end time
            if "enters_shadow" in transit_info and transit_info["enters_shadow"]["jd"] < end_jd:
                end_jd = transit_info["enters_shadow"]["jd"]
            
            # If satellite leaves shadow during pass, use that as start time if it's after elev10_rise
            if "leaves_shadow" in transit_info and transit_info["leaves_shadow"]["jd"] > start_jd:
                start_jd = max(start_jd, transit_info["leaves_shadow"]["jd"])
            
            # Calculate duration in seconds
            visible_duration = max(0, (end_jd - start_jd) * 86400.0)
        
        transit_info["visible_above_10_deg_duration_sec"] = visible_duration
        
        # Calculate visible_culmination_elev
        visible_culmination_elev = -1
        
        # If we have culmination and it's illuminated, use its elevation
        if "culmination" in transit_info and culm_obs["is_illuminated"]:
            visible_culmination_elev = culm_obs["elevation"]
        else:
            # Find the highest elevation when satellite is illuminated
            # Start with 10-degree rise if illuminated
            if "elev10_rise" in transit_info and elev10_rise_obs["is_illuminated"]:
                visible_culmination_elev = elev10_rise_obs["elevation"]
            
            # Check 10-degree set if illuminated
            if "elev10_set" in transit_info and elev10_set_obs["is_illuminated"]:
                visible_culmination_elev = max(visible_culmination_elev, elev10_set_obs["elevation"])
            
            # Check elevation at enters_shadow if applicable
            if "enters_shadow" in transit_info:
                visible_culmination_elev = max(visible_culmination_elev, transit_info["enters_shadow"]["obs"]["elevation"])
            
            # Check elevation at leaves_shadow if applicable
            if "leaves_shadow" in transit_info:
                visible_culmination_elev = max(visible_culmination_elev, transit_info["leaves_shadow"]["obs"]["elevation"])
        
        transit_info["visible_culmination_elev"] = visible_culmination_elev

        if visible_duration > 0 and visible_culmination_elev > 0:
            transit_list.append(transit_info)
    
    end_time = timing.time()
    total_time = end_time - start_time
    
    # Log summary of all calculation times
    logger.debug(
        f"find_visible_satellite_transits completed in {total_time:.3f}s, found {len(transit_list)} visible transits. "
        f"Calculation times: rise={total_rise_time:.3f}s, set={total_set_time:.3f}s, "
        f"culmination={total_culm_time:.3f}s, shadow={total_shadow_time:.3f}s, "
        f"sun_check={total_sun_check_time:.3f}s", 
        spanId=span_id
    )
    
    return transit_list

def calculate_satellite_observation_batch_jd(line1, line2, observer_lat, observer_lon, observer_alt=0, start_jd=None, start_fr=None, end_jd=None, end_fr=None, scan_interval_sec=60, includes_position_and_velocity=False, includes_elevation_velocity=False, includes_illumination=True, includes_sun_elevation=True):
    """
    Calculate satellite observation parameters using explicit Julian dates for start and end times.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float, optional): Observer's altitude in meters. Default is 0.
        start_jd (float): Starting Julian day number
        start_fr (float): Starting fraction of the day
        end_jd (float): Ending Julian day number
        end_fr (float): Ending fraction of the day
        scan_interval_sec (int, optional): Interval in seconds for scanning. Default is 60.
        includes_position_and_velocity (bool, optional): Whether to calculate position and velocity.
        includes_elevation_velocity (bool, optional): Whether to calculate apparent elevation velocity (deg/s).
        includes_illumination (bool, optional): Whether to calculate satellite illumination. Default is True.
        includes_sun_elevation (bool, optional): Whether to calculate sun elevation. Default is True.
    
    Returns:
        tuple or dict: If successful, returns a tuple containing:
            - jds (np.ndarray): Julian dates array
            - frs (np.ndarray): Fractions of day array
            - azimuths (np.ndarray): Azimuth angles in degrees
            - elevations (np.ndarray): Elevation angles in degrees
            - ranges (np.ndarray): Distance to satellite in km
            - is_illuminated (np.ndarray or None): Boolean array indicating if satellite is illuminated (if requested)
            - sun_elevations (np.ndarray or None): Sun elevation angles in degrees (if requested)
            - elevation_velocities (np.ndarray or None): Elevation velocities in deg/s (if requested)
            - r (np.ndarray or None): Position vectors (if requested), shape (n, 3)
            - v (np.ndarray or None): Velocity vectors (if requested), shape (n, 3)
            
            If an error occurs, returns a dict with error information.
    """
    try:
        # Generate sequence of Julian dates and fractions between start and end JD
        jds, frs = _stride_time_between_jd(start_jd, start_fr, end_jd, end_fr, scan_interval_sec)
        
        # Create satellite object
        satellite = Satrec.twoline2rv(line1, line2)
        
        # Initialize satellite array with a single satellite
        sat_array = SatrecArray([satellite])
        
        # Calculate satellite positions for all times in a single call
        e, r, v = sat_array.sgp4(jds, frs)
        
        # Check for errors
        if np.any(e != 0):
            error_indices = np.where(e[0] != 0)[0]
            if len(error_indices) > 0:
                first_error_idx = error_indices[0]
                error_code = e[0, first_error_idx]
                return {
                    "error": SGP4_ERRORS[error_code],
                    "jd": jds[first_error_idx] if jds is not None and len(jds) > first_error_idx else 0,
                    "fr": frs[first_error_idx] if frs is not None and len(frs) > first_error_idx else 0
                }
        
        # Create SkyCoord arrays for satellite positions
        x = r[0, :, 0] * u.km
        y = r[0, :, 1] * u.km
        z = r[0, :, 2] * u.km
        
        # Create Time objects directly from Julian dates
        observation_times = Time(jds + frs, format='jd', scale='utc')
        
        # Define observer's location
        observer_location = EarthLocation(
            lon=observer_lon * u.deg,
            lat=observer_lat * u.deg,
            height=observer_alt * u.m
        )
        
        # Create GCRS frame for each observation time
        satellites_gcrs = SkyCoord(
            x=x, y=y, z=z,
            frame=GCRS(obstime=observation_times),
            representation_type='cartesian'
        )
        
        # Define AltAz frames for the observer at each time
        altaz_frames = AltAz(obstime=observation_times, location=observer_location)
        
        # Transform satellite coordinates to AltAz
        satellites_altaz = satellites_gcrs.transform_to(altaz_frames)
        
        # Get azimuths, elevations, ranges
        azimuths = satellites_altaz.az.deg
        elevations = satellites_altaz.alt.deg
        ranges = satellites_altaz.distance.value  # in km
        
        # Calculate elevation velocity if requested
        elevation_velocity = None
        if includes_elevation_velocity:
            # Small time delta (1 second) for velocity calculation
            delta_t = 1.0 # second
            
            # Create position vectors for a point slightly in the future using vector operations
            # r_future = r + v * delta_t
            r_future = np.copy(r)
            r_future[0] = r[0] + v[0] * delta_t
            
            # Create SkyCoord arrays for future satellite positions
            x_future = r_future[0, :, 0] * u.km
            y_future = r_future[0, :, 1] * u.km
            z_future = r_future[0, :, 2] * u.km
            
            # Create GCRS coordinates for future positions
            satellites_gcrs_future = SkyCoord(
                x=x_future, y=y_future, z=z_future,
                frame=GCRS(obstime=observation_times),
                representation_type='cartesian'
            )
            
            # Transform future positions to AltAz
            satellites_altaz_future = satellites_gcrs_future.transform_to(altaz_frames)
            
            # Calculate rate of change in elevation (deg/s)
            elevation_velocity = (satellites_altaz_future.alt.deg - satellites_altaz.alt.deg) / delta_t  # deg/s
        
        # Initialize as None by default
        is_illuminated = None
        sun_elevations = None
        
        # Calculate sun-related data only if either illumination or sun elevation is requested
        if includes_illumination or includes_sun_elevation:
            # Get Sun positions for all observation times
            suns_gcrs = get_sun(observation_times)
            
            # Transform sun coordinates to AltAz for the observer
            suns_altaz = suns_gcrs.transform_to(altaz_frames)
            
            # Get sun elevations if requested
            if includes_sun_elevation:
                sun_elevations = suns_altaz.alt.deg
            
            # Calculate illumination for each satellite position if requested
            if includes_illumination:
                is_illuminated = np.zeros(len(jds), dtype=bool)
                
                # Earth's radius in km
                earth_radius = 6371.0  # km
                
                # Get satellite positions as array
                sat_pos = r[0, :, :].copy()  # Shape: (n, 3)
                
                # Get sun positions as array
                sun_xyz = np.vstack(suns_gcrs.cartesian.xyz.value).T  # Shape: (n, 3)
                
                # Calculate unit vectors from Earth to Sun
                sun_distances = np.linalg.norm(sun_xyz, axis=1)
                s_hat_sun = np.zeros_like(sun_xyz)
                valid_distances = sun_distances > 0
                s_hat_sun[valid_distances] = sun_xyz[valid_distances] / sun_distances[valid_distances, np.newaxis]
                
                # Projection of satellite positions onto Sun direction vectors
                proj_sat_onto_sun_line = np.sum(sat_pos * s_hat_sun, axis=1)
                
                # Determine if satellites are illuminated
                on_sun_side = proj_sat_onto_sun_line > 0
                
                # For satellites on night side, calculate shadow
                vec_proj_component = proj_sat_onto_sun_line[:, np.newaxis] * s_hat_sun
                vec_perp_component = sat_pos - vec_proj_component
                distance_to_shadow_axis = np.linalg.norm(vec_perp_component, axis=1)
                
                # Set illumination status
                is_illuminated = np.copy(on_sun_side)
                is_illuminated[~on_sun_side] = distance_to_shadow_axis[~on_sun_side] >= earth_radius
        
        # Only extract position and velocity if requested (to save memory)
        if not includes_position_and_velocity:
            r = None
            v = None

        # Return raw vectors instead of dictionaries
        return (
            jds, frs, 
            azimuths, elevations, ranges, 
            is_illuminated, sun_elevations, 
            elevation_velocity, 
            r, v
        )
    
    except Exception as e:
        return {
            "error": f"Batch calculation error: {str(e)}"
        }
    
def calculate_satellite_position(line1, line2, time_str=None, include_earth_projection=True):
    """
    Calculate satellite position based on TLE, observer coordinates, and time.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        time_str (str, optional): Time in ISO format (YYYY-MM-DDTHH:MM:SS).
                                 If None, current time is used.
        include_earth_projection (bool, optional): Whether to calculate and include
                                  Earth projection (longitude, latitude, altitude).
                                  Default is True.
    
    Returns:
        dict: Dictionary containing satellite information:
            - error: Error message if calculation failed, None otherwise
            - position: Dictionary with x, y, z coordinates in km
            - velocity: Dictionary with x, y, z velocities in km/s
            - earth_projection: Dictionary with longitude, latitude, altitude values
                              (only if include_earth_projection is True)
            - time: Time used for calculation
    """
    try:
        satellite = Satrec.twoline2rv(line1, line2)
        
        # Parse time or use current time
        dt, dt_without_tz = _parse_time_to_utc(time_str)
            
        year = dt.year
        month = dt.month
        day = dt.day
        hour = dt.hour
        minute = dt.minute
        second = dt.second + dt.microsecond / 1_000_000
        
        jd, fr = jday(year, month, day, hour, minute, second)
        
        error_code, position, velocity = satellite.sgp4(jd, fr)
        
        if error_code != 0:
            return {
                "error": SGP4_ERRORS[error_code],
                "position": None,
                "velocity": None,
                "earth_projection": None,
                "time": dt.isoformat()
            }
        
        earth_projection = None
        # Calculate Earth projection (longitude, latitude, altitude) if requested
        if include_earth_projection:
            # Convert datetime to astropy Time object
            observation_time = Time(dt_without_tz.isoformat(), format='isot', scale='utc')
            
            # Create SkyCoord object for the satellite in GCRS
            satellite_gcrs = SkyCoord(
                x=position[0] * u.km,
                y=position[1] * u.km,
                z=position[2] * u.km,
                frame=GCRS(obstime=observation_time),
                representation_type='cartesian'
            )
            
            try:
                # Transform from GCRS to ITRS (Earth-fixed frame)
                from astropy.coordinates import ITRS
                satellite_itrs = satellite_gcrs.transform_to(ITRS(obstime=observation_time))
                
                # Get geodetic representation (WGS84 ellipsoid)
                satellite_geodetic = satellite_itrs.represent_as('wgs84geodetic')
                
                # Create earth_projection dictionary using the geodetic coordinates
                earth_projection = {
                    "longitude": float(satellite_geodetic.lon.deg),  # longitude in degrees
                    "latitude": float(satellite_geodetic.lat.deg),   # latitude in degrees
                    "altitude": float(satellite_geodetic.height.to(u.km).value)  # altitude in km above WGS84 ellipsoid
                }
            except Exception as e:
                earth_projection = None
                print(f"Earth projection calculation failed: {str(e)}")
                
        # Return the results
        result = {
            "error": None,
            "position": {
                "x": position[0],
                "y": position[1],
                "z": position[2]
            },
            "velocity": {
                "x": velocity[0],
                "y": velocity[1],
                "z": velocity[2]
            },
            "time": dt.isoformat()
        }
        
        # Add earth_projection if calculated
        if earth_projection:
            result["earth_projection"] = earth_projection
            
        return result
    except Exception as e:
        # Use the helper function to get the time
        error_dt, _ = _parse_time_to_utc(time_str)
        result = {
            "error": str(e),
            "position": None,
            "velocity": None,
            "time": error_dt.isoformat()
        }
        
        # Only include earth_projection field if it was requested
        if include_earth_projection:
            result["earth_projection"] = None
            
        return result

def calculate_satellite_observation(sat_position, sat_velocity, observer_lat, observer_lon, observer_alt=0, time_str=None):
    """
    Calculate satellite observation parameters (azimuth, elevation, range) and sun illumination
    from a ground observer's position, given the satellite's position and velocity in ECI frame.
    
    Args:
        sat_position (dict): Satellite position with keys 'x', 'y', 'z' in km
        sat_velocity (dict): Satellite velocity with keys 'x', 'y', 'z' in km/s
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float, optional): Observer's altitude in meters. Default is 0.
        time_str (str, optional): Time in ISO format (YYYY-MM-DDTHH:MM:SS).
                                  If None, current time is used.
    
    Returns:
        dict: Dictionary containing satellite observation data:
            - error: Error message if calculation failed, None otherwise
            - azimuth: Azimuth angle in degrees
            - elevation: Elevation angle in degrees
            - range: Distance to satellite in kilometers
            - is_illuminated: Boolean indicating if the satellite is illuminated by the Sun
            - sun_elevation: Elevation angle of the Sun in degrees at observer's location
            - time: Time used for calculation
    """
    try:
        # Parse time or use current time
        dt, dt_without_tz = _parse_time_to_utc(time_str)
            
        # Convert datetime to astropy Time object
        # Remove the timezone (since it's UTC anyway) for astropy so that it doesn't throw an error
        observation_time = Time(dt_without_tz.isoformat(), format='isot', scale='utc')
        
        # Define observer's location
        observer_location = EarthLocation(
            lon=observer_lon * u.deg,
            lat=observer_lat * u.deg,
            height=observer_alt * u.m
        )
        
        # Create SkyCoord object for the satellite in GCRS (Geocentric Celestial Reference System)
        satellite_gcrs = SkyCoord(
            x=sat_position['x'] * u.km,
            y=sat_position['y'] * u.km,
            z=sat_position['z'] * u.km,
            frame=GCRS(obstime=observation_time),
            representation_type='cartesian'
        )
        
        # Define the AltAz frame for the observer
        altaz_frame = AltAz(obstime=observation_time, location=observer_location)
        
        # Transform satellite coordinates to AltAz
        satellite_altaz = satellite_gcrs.transform_to(altaz_frame)
        
        # Calculate Sun illumination
        # Get Sun's position in GCRS at the observation time
        sun_gcrs = get_sun(observation_time)
        
        # Transform sun coordinates to AltAz for the observer
        sun_altaz = sun_gcrs.transform_to(altaz_frame)
        
        # Earth's radius in km
        earth_radius = 6371 * u.km
        
        # Vector from Earth (origin) to Satellite
        vec_earth_to_satellite = satellite_gcrs.cartesian.xyz
        
        # Vector from Earth (origin) to Sun
        vec_earth_to_sun = sun_gcrs.cartesian.xyz
        
        # Unit vector Earth to Sun
        s_hat_sun = vec_earth_to_sun / np.linalg.norm(vec_earth_to_sun)
        
        # Projection of satellite's position onto the Sun direction vector
        proj_sat_onto_sun_line = vec_earth_to_satellite.dot(s_hat_sun)
        
        # Determine if satellite is illuminated
        if proj_sat_onto_sun_line > 0:
            # Satellite is on the Sun-facing side
            is_illuminated = True
        else:
            # Satellite is on the night-side
            # Calculate perpendicular distance from shadow axis
            vec_proj_component = proj_sat_onto_sun_line * s_hat_sun
            vec_perp_component = vec_earth_to_satellite - vec_proj_component
            distance_to_shadow_axis = np.linalg.norm(vec_perp_component)
            
            # If distance to shadow axis is less than Earth's radius, satellite is in shadow
            is_illuminated = not (distance_to_shadow_axis < earth_radius)
        
        # Return the results
        return {
            "error": None,
            "azimuth": satellite_altaz.az.deg,
            "elevation": satellite_altaz.alt.deg,
            "range": satellite_altaz.distance.value,  # in km
            "is_illuminated": bool(is_illuminated),
            "sun_elevation": sun_altaz.alt.deg,  # Sun elevation in degrees
            "time": dt.isoformat()
        }
    except Exception as e:
        # Use the helper function to get the time
        error_dt, _ = _parse_time_to_utc(time_str)
        return {
            "error": f"Observation calculation error: {str(e)}",
            "azimuth": None,
            "elevation": None,
            "range": None,
            "is_illuminated": None,
            "sun_elevation": None,
            "time": error_dt.isoformat()
        }

def calculate_satellite_position_and_observation(line1, line2, observer_lat, observer_lon, observer_alt=0, time_str=None, include_earth_projection=True):
    """
    Calculate satellite position, velocity, and observation parameters in one call.
    This combines calculate_satellite_position and calculate_satellite_observation.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float, optional): Observer's altitude in meters. Default is 0.
        time_str (str, optional): Time in ISO format (YYYY-MM-DDTHH:MM:SS).
                                 If None, current time is used.
        include_earth_projection (bool, optional): Whether to calculate and include
                                  Earth projection (longitude, latitude, altitude).
                                  Default is True.
    
    Returns:
        dict: Dictionary containing all satellite information:
            - error: Error message if calculation failed, None otherwise
            - position: Dictionary with x, y, z coordinates in km
            - velocity: Dictionary with x, y, z velocities in km/s
            - earth_projection: Dictionary with longitude, latitude, altitude values
                              (only if include_earth_projection is True)
            - observation: Dictionary with azimuth, elevation, range, illumination data, and sun elevation
            - time: Time used for calculation
    """
    # First get position and velocity
    result = calculate_satellite_position(line1, line2, time_str, include_earth_projection)
    
    # If there was an error, return early
    if result["error"]:
        response = {
            "error": result["error"],
            "position": None,
            "velocity": None,
            "observation": None,
            "time": result["time"]
        }
        # Only include earth_projection field if it was requested
        if include_earth_projection:
            response["earth_projection"] = None
        return response
    
    # Calculate observation data
    try:
        observation = calculate_satellite_observation(
            result["position"], 
            result["velocity"], 
            observer_lat, 
            observer_lon, 
            observer_alt, 
            time_str
        )
        
        # Check if observation calculation had errors
        if observation["error"]:
            print(f"Observation calculation error: {observation['error']}")
            response = {
                "error": observation["error"],
                "position": result["position"],
                "velocity": result["velocity"],
                "observation": None,
                "time": result["time"]
            }
            # Copy earth_projection if it exists in the result
            if "earth_projection" in result:
                response["earth_projection"] = result["earth_projection"]
            return response
        
        # Return combined results
        response = {
            "error": None,
            "position": result["position"],
            "velocity": result["velocity"],
            "observation": {
                "azimuth": observation["azimuth"],
                "elevation": observation["elevation"],
                "range": observation["range"],
                "is_illuminated": observation["is_illuminated"],
                "sun_elevation": observation["sun_elevation"]
            },
            "time": result["time"]
        }
        # Copy earth_projection if it exists in the result
        if "earth_projection" in result:
            response["earth_projection"] = result["earth_projection"]
        return response
    except Exception as e:
        response = {
            "error": f"Error calculating observation data: {str(e)}",
            "position": result["position"],
            "velocity": result["velocity"],
            "observation": None,
            "time": result["time"]
        }
        # Copy earth_projection if it exists in the result
        if "earth_projection" in result:
            response["earth_projection"] = result["earth_projection"]
        return response

def _newton_raphson_solve_for_elevation(line1, line2, observer_lat, observer_lon, observer_alt, jd, fr, 
                                target_elevation=0.0, direction='rising', max_iterations=10, tolerance=5e-1):
    """
    Helper function to find the exact time when satellite elevation reaches a specific value.
    Uses Newton-Raphson method to iteratively solve for the time.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float): Observer's altitude in meters
        jd (float): Initial Julian date
        fr (float): Initial fraction of day
        target_elevation (float, optional): Target elevation in degrees to solve for. Default is 0.0.
        direction (str): Either 'rising' or 'setting' to determine search direction
        max_iterations (int): Maximum iterations for Newton-Raphson method
        tolerance (float): Convergence tolerance for elevation in degrees
        
    Returns:
        tuple: (jd, fr, observation, error) where:
            - jd: Julian date of target elevation
            - fr: Fraction of the day of target elevation
            - observation: Dictionary containing observation data at target elevation
            - error: None if successful, otherwise error message
    """
    # Determine the time delta based on direction
    # For rising, we need to step backward; for setting, we step forward
    delta_sec = 1 if direction == 'setting' else -1
    
    curr_jd, curr_fr = jd, fr
    
    for _ in range(max_iterations):
        # Get observations at current time with elevation velocity
        obs_result = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=curr_jd, start_fr=curr_fr, end_jd=curr_jd, end_fr=curr_fr,
            scan_interval_sec=1, includes_elevation_velocity=True,
            includes_illumination=False, includes_sun_elevation=False
        )
        
        # Check if we got a valid result
        if isinstance(obs_result, dict) and "error" in obs_result:
            return None, None, None, obs_result
        
        # Extract parameters
        _, _, _, elevations, _, _, _, elevation_velocity, _, _ = obs_result
        
        # Current elevation (function value)
        elevation = elevations[0]
        
        # If we're close enough to target elevation, return result
        if abs(elevation - target_elevation) < tolerance:
            obs_result = calculate_satellite_observation_batch_jd(
                line1, line2, observer_lat, observer_lon, observer_alt,
                start_jd=curr_jd, start_fr=curr_fr, end_jd=curr_jd, end_fr=curr_fr,
                scan_interval_sec=1
            )
            _, _, azimuths, elevations, ranges, is_illuminated, sun_elevations, _, _, _ = obs_result
            return curr_jd, curr_fr, {
                "azimuth": azimuths[0],
                "elevation": elevations[0],
                "range": ranges[0],
                "is_illuminated": bool(is_illuminated[0]),
                "sun_elevation": sun_elevations[0]
            }, None
        
        # If elevation velocity is not available or zero, use small time step method instead
        if elevation_velocity is None or abs(elevation_velocity[0]) < 1e-2:
            # Use small time steps
            delta_jd = delta_sec / 86400.0  # Convert seconds to fraction of day
            curr_jd, curr_fr = _update_jd_fr(curr_jd, curr_fr, delta_jd)
            continue
        
        # Use Newton-Raphson: x_next = x - f(x)/f'(x)
        # Here f(x) is (elevation - target_elevation), f'(x) is elevation_velocity
        # We're solving for elevation=target_elevation, so we have: x_next = x - (elevation - target_elevation)/elevation_velocity
        # Convert this time delta to jd, fr format
        delta_time_seconds = -(elevation - target_elevation) / elevation_velocity[0]
        delta_jd = delta_time_seconds / 86400.0  # Convert seconds to fraction of day
        
        # Update jd and fr
        curr_jd, curr_fr = _update_jd_fr(curr_jd, curr_fr, delta_jd)
    
    # If we reach here, we've exceeded max iterations
    return None, None, None, {"error": "Max iterations exceeded in Newton-Raphson method."}

def _find_culmination_point(line1, line2, observer_lat, observer_lon, observer_alt, 
                           rise_jd, rise_fr, set_jd, set_fr, scan_interval_sec=15, tolerance=1e-1):
    """
    Helper function to find the culmination point (maximum elevation) of a satellite transit.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float): Observer's altitude in meters
        rise_jd (float): Julian date of rise time
        rise_fr (float): Fraction of day of rise time
        set_jd (float): Julian date of set time
        set_fr (float): Fraction of day of set time
        scan_interval_sec (int): Interval in seconds for scanning between rise and set
        
    Returns:
        tuple: (jd, fr, observation) containing the culmination point data
    """
    # First, scan the transit at a coarse resolution to find approximate culmination
    jds, frs = _stride_time_between_jd(rise_jd, rise_fr, set_jd, set_fr, scan_interval_sec)
    
    # Get observations for the whole pass
    obs_result = calculate_satellite_observation_batch_jd(
        line1, line2, observer_lat, observer_lon, observer_alt,
        start_jd=jds[0], start_fr=frs[0], end_jd=jds[-1], end_fr=frs[-1],
        scan_interval_sec=scan_interval_sec, includes_elevation_velocity=True
    )
    
    # Check if we got a valid result
    if isinstance(obs_result, dict) and "error" in obs_result:
        return None, None, None
    
    # Extract parameters
    _, _, azimuths, elevations, ranges, is_illuminated, sun_elevations, elevation_velocities, _, _ = obs_result
    
    # Find index of maximum elevation
    max_index = np.argmax(elevations)
    
    # If max index is at the edges, our scan might be incomplete
    if max_index == 0 or max_index == len(elevations) - 1:
        return None, None, None
    
    # For a more precise measurement, look for where elevation velocity changes sign
    # This happens at the culmination point
    elev_vel_signs = np.sign(elevation_velocities)
    sign_changes = np.where(np.diff(elev_vel_signs))[0]
    
    # If we found sign changes and they occur after rise and before set
    if len(sign_changes) > 0:
        # Find the sign change with the highest elevation
        best_idx = max_index  # Default to the max elevation point
        for idx in sign_changes:
            if elevations[idx] > elevations[best_idx]:
                best_idx = idx
        
        # Double check that this is a positive to negative transition (apex)
        if best_idx > 0 and best_idx < len(elevation_velocities) - 1:
            if elevation_velocities[best_idx-1] > 0 and elevation_velocities[best_idx+1] < 0:
                max_index = best_idx
    
    # Refine culmination with Newton-Raphson if elevation velocity is available
    culm_jd, culm_fr = jds[max_index], frs[max_index]
    
    # Use a few iterations of Newton-Raphson to refine where elevation velocity is zero
    for _ in range(5):
        # Get elevation velocity at this point
        obs_result = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=culm_jd, start_fr=culm_fr, end_jd=culm_jd, end_fr=culm_fr,
            scan_interval_sec=1, includes_elevation_velocity=True
        )
        
        if isinstance(obs_result, dict) and "error" in obs_result:
            break
            
        _, _, azimuths, elevations, ranges, is_illuminated, sun_elevations, elevation_velocity, _, _ = obs_result
        
        if elevation_velocity is None or abs(elevation_velocity[0]) < 1e-4:
            break
            
        # Use Newton-Raphson to find where derivative (elevation velocity) is zero
        # This requires second derivative, which we estimate using finite difference
        delta_sec = 1.0
        delta_jd = delta_sec / 86400.0
        
        # Get elevation velocity at t+delta
        next_jd, next_fr = _update_jd_fr(culm_jd, culm_fr, delta_jd)
        obs_result_next = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=next_jd, start_fr=next_fr, end_jd=next_jd, end_fr=next_fr,
            scan_interval_sec=1, includes_elevation_velocity=True,
            includes_illumination=False, includes_sun_elevation=False
        )
        
        if isinstance(obs_result_next, dict) and "error" in obs_result_next:
            break
            
        _, _, _, _, _, _, _, elevation_velocity_next, _, _ = obs_result_next
        
        if elevation_velocity_next is None:
            break
            
        # Estimate second derivative
        elevation_acceleration = (elevation_velocity_next[0] - elevation_velocity[0]) / delta_sec
        
        if abs(elevation_acceleration) < 1e-5:
            break
            
        # Newton step: t_new = t - f'(t) / f''(t)
        delta_time_seconds = -elevation_velocity[0] / elevation_acceleration
        delta_jd = delta_time_seconds / 86400.0
        
        # Update and keep within reasonable bounds
        if abs(delta_jd) > scan_interval_sec / 86400.0:
            delta_jd = np.sign(delta_jd) * scan_interval_sec / 86400.0
            
        culm_jd, culm_fr = _update_jd_fr(culm_jd, culm_fr, delta_jd)
        
        # If we're already very precise, stop
        if abs(elevation_velocity[0]) < tolerance:
            break

    # Get the final observation at culmination point
    final_obs_result = calculate_satellite_observation_batch_jd(
        line1, line2, observer_lat, observer_lon, observer_alt,
        start_jd=culm_jd, start_fr=culm_fr, end_jd=culm_jd, end_fr=culm_fr,
        scan_interval_sec=1
    )
    
    if isinstance(final_obs_result, dict) and "error" in final_obs_result:
        return None, None, None
        
    _, _, azimuths, elevations, ranges, is_illuminated, sun_elevations, _, _, _ = final_obs_result
    
    return culm_jd, culm_fr, {
        "azimuth": azimuths[0],
        "elevation": elevations[0],
        "range": ranges[0],
        "is_illuminated": bool(is_illuminated[0]),
        "sun_elevation": sun_elevations[0]
    }

def _find_shadow_transition_points(line1, line2, observer_lat, observer_lon, observer_alt, 
                                 rise_jd, rise_fr, set_jd, set_fr):
    """
    Helper function to find exact times when a satellite enters or leaves Earth's shadow.
    
    Args:
        line1 (str): First line of TLE
        line2 (str): Second line of TLE
        observer_lat (float): Observer's latitude in degrees
        observer_lon (float): Observer's longitude in degrees
        observer_alt (float): Observer's altitude in meters
        rise_jd (float): Julian date of rise time
        rise_fr (float): Fraction of day of rise time
        set_jd (float): Julian date of set time
        set_fr (float): Fraction of day of set time
        
    Returns:
        tuple: (enters_shadow, leaves_shadow) where each is either None or a tuple (jd, fr, observation)
    """
    # If the transit is too long, use a coarse scan first, then refine
    if (set_jd + set_fr - rise_jd - rise_fr) * 86400.0 > 180:  # More than 3 min
        # Do a coarse scan first (1 minute intervals)
        coarse_jds, coarse_frs = _stride_time_between_jd(rise_jd, rise_fr, set_jd, set_fr, 60)
        
        coarse_result = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=coarse_jds[0], start_fr=coarse_frs[0], 
            end_jd=coarse_jds[-1], end_fr=coarse_frs[-1],
            scan_interval_sec=60, includes_illumination=True, includes_sun_elevation=False
        )
        
        if isinstance(coarse_result, dict) and "error" in coarse_result:
            return None, None
            
        _, _, _, _, _, is_illuminated, _, _, _, _ = coarse_result
        
        # Find where illumination changes
        shadow_changes = np.where(np.diff(is_illuminated))[0]
        
        if len(shadow_changes) == 0:
            return None, None
            
        # Create targeted scans around the transition points
        enters_shadow = None
        leaves_shadow = None
        
        for idx in shadow_changes:
            # Buffer window (1 minute before and after the change)
            before_jd, before_fr = coarse_jds[idx], coarse_frs[idx]
            after_jd, after_fr = coarse_jds[idx+1], coarse_frs[idx+1]
            
            # Determine type of transition
            is_entering_shadow = is_illuminated[idx] and not is_illuminated[idx+1]
            
            # Scan this window with 1-second resolution
            fine_jds, fine_frs = _stride_time_between_jd(before_jd, before_fr, after_jd, after_fr, 1)
            
            fine_result = calculate_satellite_observation_batch_jd(
                line1, line2, observer_lat, observer_lon, observer_alt,
                start_jd=fine_jds[0], start_fr=fine_frs[0], 
                end_jd=fine_jds[-1], end_fr=fine_frs[-1],
                scan_interval_sec=1
            )
            
            if isinstance(fine_result, dict) and "error" in fine_result:
                continue
                
            _, _, azimuths, elevations, ranges, fine_is_illuminated, sun_elevations, _, _, _ = fine_result
            
            # Find the exact transition
            fine_changes = np.where(np.diff(fine_is_illuminated))[0]
            
            if len(fine_changes) > 0:
                idx_change = fine_changes[0]  # Take the first change
                
                transition_jd, transition_fr = fine_jds[idx_change], fine_frs[idx_change]
                transition_data = {
                    "azimuth": azimuths[idx_change],
                    "elevation": elevations[idx_change],
                    "range": ranges[idx_change],
                    "is_illuminated": bool(fine_is_illuminated[idx_change]),
                    "sun_elevation": sun_elevations[idx_change]
                }
                
                if is_entering_shadow:
                    # Convert JD to ISO format datetime string using astropy Time
                    transition_time = Time(transition_jd + transition_fr, format='jd').isot
                    enters_shadow = {"jd": transition_jd + transition_fr, "time": transition_time, "obs": transition_data}
                else:
                    # Convert JD to ISO format datetime string using astropy Time
                    transition_time = Time(transition_jd + transition_fr, format='jd').isot
                    leaves_shadow = {"jd": transition_jd + transition_fr, "time": transition_time, "obs": transition_data}
    else:
        # Scan with 1-second intervals to catch shadow transitions
        jds, frs = _stride_time_between_jd(rise_jd, rise_fr, set_jd, set_fr, 1)
    
        result = calculate_satellite_observation_batch_jd(
            line1, line2, observer_lat, observer_lon, observer_alt,
            start_jd=jds[0], start_fr=frs[0], end_jd=jds[-1], end_fr=frs[-1],
            scan_interval_sec=1
        )
        
        if isinstance(result, dict) and "error" in result:
            return None, None
            
        _, _, azimuths, elevations, ranges, is_illuminated, sun_elevations, _, _, _ = result
        
        # Find where illumination changes
        shadow_changes = np.where(np.diff(is_illuminated))[0]
        
        if len(shadow_changes) == 0:
            return None, None
            
        enters_shadow = None
        leaves_shadow = None
        
        for idx in shadow_changes:
            # Determine type of transition
            is_entering_shadow = is_illuminated[idx] and not is_illuminated[idx+1]
            
            transition_jd, transition_fr = jds[idx], frs[idx]
            transition_data = {
                "azimuth": azimuths[idx],
                "elevation": elevations[idx],
                "range": ranges[idx],
                "is_illuminated": bool(is_illuminated[idx]),
                "sun_elevation": sun_elevations[idx]
            }
            
            if is_entering_shadow:
                enters_shadow = (transition_jd, transition_fr, transition_data)
            else:
                leaves_shadow = (transition_jd, transition_fr, transition_data)
    
    return enters_shadow, leaves_shadow

def _update_jd_fr(jd, fr, delta_jd):
    """
    Helper function to update Julian date and fraction, ensuring that the integer part
    of the Julian date always has a .5 fraction (standard for Julian dates where days
    begin at noon).
    
    Args:
        jd (float): Julian date
        fr (float): Fraction of day
        delta_jd (float): Change in Julian date (can be positive or negative)
        
    Returns:
        tuple: (new_jd, new_fr)
    """
    # Calculate total JD
    total_jd = jd + fr + delta_jd
    
    # Separate into integer and fractional parts, keeping the standard 0.5 offset
    new_jd = int(total_jd + 0.5) - 0.5
    new_fr = total_jd - new_jd
    
    return new_jd, new_fr

def _stride_time_between_jd(start_jd, start_fr, end_jd, end_fr, interval_sec=60):
    """
    Generates a sequence of Julian dates between two Julian dates with regular intervals.
    
    Parameters:
    ----------
    start_jd : float
        Starting Julian day number.
    start_fr : float
        Starting fraction of the day.
    end_jd : float
        Ending Julian day number.
    end_fr : float
        Ending fraction of the day.
    interval_sec : int or float, default=60
        Time interval between steps in seconds.
    
    Returns:
    -------
    jds : numpy.ndarray
        Array of Julian dates.
    frs : numpy.ndarray
        Array of fractions of the day corresponding to the Julian dates.
    """
    # Calculate total Julian days
    start_total_jd = start_jd + start_fr
    end_total_jd = end_jd + end_fr
    
    # Calculate the time difference in days
    days_diff = end_total_jd - start_total_jd
    
    # Ensure positive time difference
    if days_diff < 0:
        raise ValueError("End time must be equal or after start time")
    
    # Calculate number of steps
    secs_in_day = 86400.0
    steps = int((days_diff * secs_in_day) / interval_sec) + 1
    
    # Initialize arrays
    jds = np.zeros(steps)
    frs = np.zeros(steps)
    
    # Fill the arrays with evenly spaced time steps
    jds[0] = start_jd
    frs[0] = start_fr
    
    # Add time increment in fractional days
    day_fraction = interval_sec / secs_in_day
    
    # Calculate intermediate points
    for i in range(1, steps):
        frs[i] = frs[0] + (i * day_fraction)
        jds[i] = jds[0] + int(frs[i])
        frs[i] = frs[i] % 1.0
    
    return jds, frs

def _parse_time_to_utc(time_str=None):
    """
    Parse a time string in ISO format to a datetime object in UTC.
    If time_str is None, current time is used.
    
    Args:
        time_str (str, optional): Time in ISO format (YYYY-MM-DDTHH:MM:SS).
                                 If None, current time is used.
    
    Returns:
        tuple: (datetime, dt_without_tz) where:
            - datetime: Datetime object in UTC
            - dt_without_tz: Same datetime with tzinfo set to None (for astropy)
    """
    if time_str:
        dt = datetime.fromisoformat(time_str)
        # If time has timezone info, convert to UTC
        if dt.tzinfo is not None:
            dt = dt.astimezone(UTC)
    else:
        dt = datetime.now(UTC)
        
    # Create a timezone-naive copy for astropy (since it's UTC anyway)
    dt_without_tz = dt.replace(tzinfo=None)
    
    return dt, dt_without_tz
