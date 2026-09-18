#!/usr/bin/env python3
from typing import Optional, Tuple
import math
import numpy as np

# Spherical Earth mean radius (meters)
EARTH_MEAN_RADIUS_M = 6371008.8


def ray_sphere_intersection(origin_ecef_m: np.ndarray, dir_ecef_unit: np.ndarray, radius_m: float) -> Optional[np.ndarray]:
    """
    Intersect a ray (origin + t*dir, t>=0) with a sphere of radius `radius_m`
    centered at Earth's center. Returns closest positive intersection in ECEF meters
    or None if no intersection.
    """
    p = origin_ecef_m
    d = dir_ecef_unit
    # Quadratic: |p + t d|^2 = R^2 => t^2 + 2(d·p)t + (|p|^2 - R^2) = 0, since |d|=1
    dp = float(np.dot(d, p))
    c = float(np.dot(p, p) - radius_m * radius_m)
    disc = dp * dp - c
    if disc < 0:
        return None
    sqrt_disc = math.sqrt(disc)
    t1 = -dp - sqrt_disc
    t2 = -dp + sqrt_disc
    ts = [t for t in (t1, t2) if t >= 0.0]
    if not ts:
        return None
    t = min(ts)
    return p + t * d


def ecef_to_spherical_latlon_deg(xyz_m: np.ndarray) -> Tuple[float, float]:
    """Convert ECEF to spherical lat/lon in degrees using simple spherical model."""
    x, y, z = map(float, xyz_m)
    r = math.sqrt(x * x + y * y + z * z)
    if r == 0:
        return 0.0, 0.0
    lat = math.degrees(math.asin(z / r))
    lon = math.degrees(math.atan2(y, x))
    return lat, lon

