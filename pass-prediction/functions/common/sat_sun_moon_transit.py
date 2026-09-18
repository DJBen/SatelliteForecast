#!/usr/bin/env python3
# Copyright 2025
#
# Helper utilities to compute the Sun/Moon transit footprint on Earth by
# intersecting the conic surface of rays (defined by the apparent angular
# radius of the Sun or Moon as seen from the satellite) with the WGS84
# ellipsoid. This produces a closed polygon (approximate ellipse) on the
# Earth surface, independent of any specific observer location.

from typing import List, Tuple, Optional, Dict, Any

import math
import numpy as np

import astropy.units as u
from astropy.coordinates import GCRS, ITRS, SkyCoord, get_sun, get_body
from astropy.time import Time

from sgp4.api import Satrec, jday

try:
    # Optional dependencies
    from shapely.geometry import Polygon  # type: ignore
    _HAVE_SHAPELY = True
except Exception:
    _HAVE_SHAPELY = False

from datetime import datetime, timezone
def _parse_time_to_utc(time_str: Optional[str] = None):
    """Parse ISO time string to UTC datetime and naive UTC copy.

    Accepts trailing 'Z' by converting to '+00:00' for Python <3.11.
    """
    if time_str:
        s = time_str.strip()
        if s.endswith('Z') or s.endswith('z'):
            s = s[:-1] + '+00:00'
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is not None:
            dt = dt.astimezone(timezone.utc)
        else:
            dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = datetime.now(timezone.utc)
    dt_without_tz = dt.replace(tzinfo=None)
    return dt, dt_without_tz

# WGS84 ellipsoid (meters)
WGS84_A = 6378137.0                # Equatorial radius (a)
WGS84_B = 6356752.314245           # Polar radius (b)

# Body radii (kilometers)
SUN_RADIUS_KM = 695700.0
MOON_RADIUS_KM = 1737.4

def _satellite_gcrs_position(line1: str, line2: str, t: Time) -> SkyCoord:
    """
    Compute satellite position in GCRS at time t using SGP4 and return as SkyCoord.

    Returns a SkyCoord with representation_type='cartesian' and km units.
    """
    # Convert astropy Time to SGP4 julian day/fraction
    jd_float = t.jd
    jd = math.floor(jd_float + 0.5) - 0.5
    fr = jd_float - jd

    sat = Satrec.twoline2rv(line1, line2)
    e, r, v = sat.sgp4(jd, fr)
    if e != 0:
        raise RuntimeError(f"SGP4 error code: {e}")

    x_km, y_km, z_km = r  # km
    return SkyCoord(x=x_km * u.km, y=y_km * u.km, z=z_km * u.km,
                    frame=GCRS(obstime=t), representation_type='cartesian')


def _body_gcrs_position(body: str, t: Time) -> SkyCoord:
    """
    Get body position in GCRS at time t.
    body: 'sun' or 'moon'
    """
    if body.lower() == 'sun':
        sc = get_sun(t)
        # Ensure frame is GCRS
        if not isinstance(sc.frame, GCRS):
            sc = sc.transform_to(GCRS(obstime=t))
        return sc
    elif body.lower() == 'moon':
        sc = get_body('moon', t)
        if not isinstance(sc.frame, GCRS):
            sc = sc.transform_to(GCRS(obstime=t))
        return sc
    else:
        raise ValueError("body must be 'sun' or 'moon'")


def _cone_directions(axis: np.ndarray, theta: float, num_points: int = 180) -> Tuple[np.ndarray, np.ndarray]:
    """
    Generate unit direction vectors for both nappes of a cone around 'axis' with half-angle 'theta'.

    axis: unit vector (3,) defining the axis direction.
    theta: half-angle in radians
    Returns a tuple (dirs_forward, dirs_backward), each of shape (num_points, 3)
    where 'forward' is +axis nappe and 'backward' is -axis nappe.
    """
    z = axis / np.linalg.norm(axis)
    # Choose an arbitrary vector not parallel to z to build basis
    arbitrary = np.array([1.0, 0.0, 0.0]) if abs(z[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
    x = np.cross(arbitrary, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)

    angles = np.linspace(0.0, 2.0 * np.pi, num_points, endpoint=False)
    circle = np.cos(angles)[:, None] * x[None, :] + np.sin(angles)[:, None] * y[None, :]

    # Two nappes: along +z and -z
    dirs_forward = np.cos(theta) * z[None, :] + np.sin(theta) * circle
    dirs_backward = -np.cos(theta) * z[None, :] + np.sin(theta) * circle

    # Normalize (defensive)
    dirs_forward /= np.linalg.norm(dirs_forward, axis=1)[:, None]
    dirs_backward /= np.linalg.norm(dirs_backward, axis=1)[:, None]
    return dirs_forward, dirs_backward


def _compute_itrs_linearization(origin_gcrs: SkyCoord, t: Time) -> Tuple[np.ndarray, np.ndarray]:
    """
    Compute a first-order linearization (Jacobian) to map small GCRS increments
    near the satellite to ITRS increments. This lets us transform many direction
    vectors cheaply without calling astropy transforms for each ray.

    Returns (origin_ecef_m, J) where J is a 3x3 matrix such that for a small
    increment dv_gcrs (in km), the corresponding increment in ECEF meters is:
        dv_ecef_m ≈ J @ dv_gcrs
    """
    # Base point in GCRS and ITRS
    p_gcrs = origin_gcrs
    p_itrs = p_gcrs.transform_to(ITRS(obstime=t))
    p_ecef = np.vstack(p_itrs.cartesian.xyz.to_value(u.m)).ravel()

    # Basis increments in GCRS (km)
    step_km = 10.0
    basis = np.eye(3) * step_km

    cols = []
    for i in range(3):
        dp = basis[i]
        q_gcrs = SkyCoord(
            x=(p_gcrs.cartesian.x + dp[0] * u.km),
            y=(p_gcrs.cartesian.y + dp[1] * u.km),
            z=(p_gcrs.cartesian.z + dp[2] * u.km),
            frame=GCRS(obstime=t), representation_type='cartesian'
        )
        q_itrs = q_gcrs.transform_to(ITRS(obstime=t))
        q_ecef = np.vstack(q_itrs.cartesian.xyz.to_value(u.m)).ravel()
        # Column is delta_ecef / step_km
        cols.append((q_ecef - p_ecef) / step_km)

    J = np.column_stack(cols)  # shape (3,3), meters per km
    return p_ecef, J


def _map_dir_gcrs_to_itrs(dir_gcrs_unit: np.ndarray, J: np.ndarray) -> np.ndarray:
    """Map a GCRS unit direction to ITRS using the Jacobian, returning a unit vector in ECEF."""
    v = J @ dir_gcrs_unit  # meters per km; magnitude irrelevant, normalize
    return v / np.linalg.norm(v)


def _ray_wgs84_intersection(origin_ecef_m: np.ndarray, dir_ecef_unit: np.ndarray) -> Optional[np.ndarray]:
    """
    Intersect a ray (origin + t*dir, t >= 0) with the WGS84 ellipsoid.
    Returns the intersection point in ECEF meters if it exists; otherwise None.
    """
    px, py, pz = origin_ecef_m
    dx, dy, dz = dir_ecef_unit

    a2 = WGS84_A * WGS84_A
    b2 = WGS84_B * WGS84_B

    A = (dx*dx + dy*dy) / a2 + (dz*dz) / b2
    B = 2.0 * ((px*dx + py*dy) / a2 + (pz*dz) / b2)
    C = (px*px + py*py) / a2 + (pz*pz) / b2 - 1.0

    disc = B*B - 4.0*A*C
    if disc < 0.0 or A == 0.0:
        return None

    sqrt_disc = math.sqrt(disc)
    t1 = (-B - sqrt_disc) / (2.0*A)
    t2 = (-B + sqrt_disc) / (2.0*A)

    ts = [t for t in (t1, t2) if t >= 0.0]
    if not ts:
        return None
    t = min(ts)
    return origin_ecef_m + t * dir_ecef_unit


def _ecef_to_geodetic_deg(xyz_m: np.ndarray) -> Tuple[float, float, float]:
    """
    Convert ECEF meters to (lat_deg, lon_deg, height_m) using astropy EarthLocation.
    """
    from astropy.coordinates import EarthLocation
    loc = EarthLocation.from_geocentric(xyz_m[0]*u.m, xyz_m[1]*u.m, xyz_m[2]*u.m)
    return float(loc.lat.deg), float(loc.lon.deg), float(loc.height.to_value(u.m))

def compute_transit_footprint(
    line1: str,
    line2: str,
    time_str: Optional[str] = None,
    body: str = 'sun',
    num_points: int = 180,
    return_shapely: bool = False,
) -> Optional[Dict[str, Any]]:
    """
    Compute the Sun/Moon transit footprint on the Earth's surface at a given time.

    The footprint is the intersection of a cone defined by the body's apparent
    angular radius (as seen from the satellite) and the WGS84 ellipsoid.

    Args:
        line1, line2: TLE lines
        time_str: ISO time. If None, uses current UTC.
        body: 'sun' or 'moon'
        num_points: number of boundary samples
        return_shapely: include a shapely Polygon if shapely is available

    Returns:
        dict with keys, or None if the cone does not intersect Earth:
          - 'time': ISO timestamp
          - 'center': {'lat': float|None, 'lon': float|None}
          - 'subsat': {'lat': float, 'lon': float, 'height_m': float}
          - 'lats': List[float]
          - 'lons': List[float]
          - 'polygon': shapely.geometry.Polygon (optional, if requested and available)
          - 'meta': { 'cone_angle_deg': float, 'body': str }
    """
    dt, dt_naive = _parse_time_to_utc(time_str)
    t = Time(dt_naive.isoformat(), format='isot', scale='utc')

    # Positions in GCRS
    sat_gcrs = _satellite_gcrs_position(line1, line2, t)
    body_gcrs = _body_gcrs_position(body, t)

    # Axis from body to satellite (GCRS)
    sat_xyz_km = np.vstack(sat_gcrs.cartesian.xyz.to_value(u.km)).ravel()
    body_xyz_km = np.vstack(body_gcrs.cartesian.xyz.to(u.km).value).ravel()
    axis_gcrs = sat_xyz_km - body_xyz_km
    axis_unit = axis_gcrs / np.linalg.norm(axis_gcrs)

    # Cone half-angle: body's apparent angular radius seen from satellite
    dist_km = np.linalg.norm(axis_gcrs)
    if body.lower() == 'sun':
        theta = math.asin(min(1.0, SUN_RADIUS_KM / dist_km))
    elif body.lower() == 'moon':
        theta = math.asin(min(1.0, MOON_RADIUS_KM / dist_km))
    else:
        raise ValueError("body must be 'sun' or 'moon'")

    # Build directions around the cone in GCRS (we'll start coarse and optionally densify)
    # Compute ITRS linearization once
    origin_ecef, J = _compute_itrs_linearization(sat_gcrs, t)

    # Sub-satellite point (ground track) from satellite ECEF position
    subsat_lat, subsat_lon, subsat_h = _ecef_to_geodetic_deg(origin_ecef)
    to_earth_center = -origin_ecef  # vector from satellite to Earth's center in ECEF

    # Determine which nappe faces Earth by comparing axis directions
    axis_forward = axis_unit
    axis_backward = -axis_unit
    d_fwd = _map_dir_gcrs_to_itrs(axis_forward, J)
    d_back = _map_dir_gcrs_to_itrs(axis_backward, J)
    use_forward = (np.dot(d_fwd, to_earth_center) > np.dot(d_back, to_earth_center))

    # Quick culling: check if the cone can possibly intersect Earth using axial closest approach
    axis_dir_gcrs = axis_unit if use_forward else -axis_unit
    axis_dir_itrs = _map_dir_gcrs_to_itrs(axis_dir_gcrs, J)
    # Ray from satellite: p(t)=origin_ecef + t*axis_dir_itrs, t>=0
    t0 = -float(np.dot(axis_dir_itrs, origin_ecef))  # meters since origin_ecef in m, dir unitless
    if t0 <= 0:
        return None
    closest = origin_ecef + t0 * axis_dir_itrs
    dmin = float(np.linalg.norm(closest))  # meters to Earth's center
    radial_margin = t0 * math.tan(theta) + 1000.0  # meters; include small safety
    if dmin > (WGS84_A + radial_margin):
        return None

    # Compute center line intersections (ellipsoid and optional sphere)
    center_pt = _ray_wgs84_intersection(origin_ecef, axis_dir_itrs)
    center_lat, center_lon = (None, None)
    if center_pt is not None:
        center_lat, center_lon, _ = _ecef_to_geodetic_deg(center_pt)

    # Sample boundary rays (coarse first)
    lats: List[float] = []
    lons: List[float] = []

    coarse = min(60, max(16, num_points // 3 if num_points > 24 else num_points))
    dirs_fwd_gcrs, dirs_back_gcrs = _cone_directions(axis_unit, theta, num_points=coarse)
    dirs_gcrs = dirs_fwd_gcrs if use_forward else dirs_back_gcrs

    has_any = False
    hit_flags = []
    pts_ecef = []
    for dir_gcrs in dirs_gcrs:
        d_itrs = _map_dir_gcrs_to_itrs(dir_gcrs, J)
        pt = _ray_wgs84_intersection(origin_ecef, d_itrs)
        if pt is None:
            hit_flags.append(False)
            pts_ecef.append(None)
            continue
        has_any = True
        hit_flags.append(True)
        pts_ecef.append(pt)
        lat_deg, lon_deg, _ = _ecef_to_geodetic_deg(pt)
        lats.append(lat_deg)
        lons.append(lon_deg)

    if not has_any:
        # No boundary intersections -> no footprint
        return None

    # Optional densification if many hits and requested num_points is larger
    if num_points > coarse and sum(hit_flags) >= 4:
        cur_angles = list(np.linspace(0.0, 2.0 * np.pi, coarse, endpoint=False))
        cur_lats = lats[:]
        cur_lons = lons[:]
        # Map indices of hits to their lat/lon
        hits = [(i, cur_angles[i]) for i, ok in enumerate(hit_flags) if ok]
        # We'll insert midpoints between consecutive hit rays until we reach num_points or 2 rounds
        rounds = 0
        while len(cur_lats) < num_points and rounds < 2:
            new_angles = []
            new_coords: List[Tuple[float, float]] = []
            # Iterate over angle indices cyclically
            hit_indices = [i for i, ok in enumerate(hit_flags) if ok]
            if len(hit_indices) < 2:
                break
            for a, b in zip(hit_indices, hit_indices[1:] + hit_indices[:1]):
                # mid-angle between a and b (account for wraparound)
                ang_a = cur_angles[a]
                ang_b = cur_angles[b]
                # Normalize ang_b after ang_a
                if ang_b < ang_a:
                    ang_b += 2.0 * np.pi
                ang_m = (ang_a + ang_b) * 0.5
                ang_m = (ang_m % (2.0 * np.pi))
                new_angles.append(ang_m)
            # Evaluate new angles
            for ang in new_angles:
                dir_ring = np.cos(ang) * (dirs_gcrs[0] * 0 + 1)  # placeholder; we need basis x,y around axis
            # Build local basis around axis to evaluate arbitrary angle
            z = axis_unit / np.linalg.norm(axis_unit)
            arbitrary = np.array([1.0, 0.0, 0.0]) if abs(z[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
            x = np.cross(arbitrary, z); x /= np.linalg.norm(x)
            y = np.cross(z, x)
            for ang in new_angles:
                dir_g = np.cos(theta) * z + np.sin(theta) * (np.cos(ang) * x + np.sin(ang) * y)
                dir_itrs = _map_dir_gcrs_to_itrs(dir_g, J)
                pt = _ray_wgs84_intersection(origin_ecef, dir_itrs)
                if pt is not None:
                    lat_deg, lon_deg, _ = _ecef_to_geodetic_deg(pt)
                    new_coords.append((lat_deg, lon_deg))
            # Append new points
            for lat_deg, lon_deg in new_coords:
                cur_lats.append(lat_deg)
                cur_lons.append(lon_deg)
            rounds += 1
        lats, lons = cur_lats, cur_lons

    result: Dict[str, Any] = {
        'time': t.isot,
        'center': {'lat': center_lat, 'lon': center_lon},
        'subsat': {'lat': subsat_lat, 'lon': subsat_lon, 'height_m': subsat_h},
        'lats': lats,
        'lons': lons,
        'meta': {
            'cone_angle_deg': math.degrees(theta),
            'body': body.lower()
        }
    }

    if return_shapely and _HAVE_SHAPELY and lats and lons:
        coords = list(zip(lons, lats))
        if coords[0] != coords[-1]:
            coords.append(coords[0])
        try:
            result['polygon'] = Polygon(coords)
        except Exception:
            pass

    return result


def compute_transit_footprints_over_range(
    line1: str,
    line2: str,
    start_time_str: str,
    end_time_str: str,
    step_seconds: float = 1.0,
    body: str = 'sun',
    num_points: int = 180,
    return_shapely: bool = False,
) -> List[Dict[str, Any]]:
    """
    Generate a series of transit footprints over a time range.

    Args:
        start_time_str, end_time_str: ISO strings (timezone allowed)
        step_seconds: sampling interval in seconds
        body: 'sun' or 'moon'
        num_points: boundary sampling resolution
        return_shapely: include shapely Polygon objects if available

    Returns:
        List of dicts as returned by compute_transit_footprint; entries are
        only included for times where an intersection exists.
    """
    from datetime import timedelta

    start_dt, start_naive = _parse_time_to_utc(start_time_str)
    end_dt, end_naive = _parse_time_to_utc(end_time_str)

    # Build a list of Time objects
    times: List[Time] = []
    t_cur = start_naive
    while t_cur <= end_naive:
        times.append(Time(t_cur.isoformat(), format='isot', scale='utc'))
        t_cur = t_cur + timedelta(seconds=step_seconds)

    out: List[Dict[str, Any]] = []
    for t in times:
        # Reuse compute_transit_footprint logic by passing a concrete isot time
        res = compute_transit_footprint(
            line1, line2, time_str=t.isot, body=body,
            num_points=num_points, return_shapely=return_shapely
        )
        if res is not None:
            out.append(res)

    return out
