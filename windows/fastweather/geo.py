"""Geospatial helpers: distance, bearing, and destination-point math."""

import math

EARTH_RADIUS_KM = 6371.0088

CARDINALS_8 = [
    ("N", 0), ("NE", 45), ("E", 90), ("SE", 135),
    ("S", 180), ("SW", 225), ("W", 270), ("NW", 315),
]


def haversine_km(lat1, lon1, lat2, lon2):
    """Great-circle distance in kilometers."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = (math.sin(dphi / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2)
    return 2 * EARTH_RADIUS_KM * math.asin(min(1.0, math.sqrt(a)))


def bearing_deg(lat1, lon1, lat2, lon2):
    """Initial bearing from point 1 to point 2, in degrees [0, 360)."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def destination_point(lat, lon, bearing, distance_km):
    """Point reached from (lat, lon) heading `bearing` for `distance_km`."""
    ang = distance_km / EARTH_RADIUS_KM
    br = math.radians(bearing)
    p1 = math.radians(lat)
    l1 = math.radians(lon)
    p2 = math.asin(math.sin(p1) * math.cos(ang)
                   + math.cos(p1) * math.sin(ang) * math.cos(br))
    l2 = l1 + math.atan2(
        math.sin(br) * math.sin(ang) * math.cos(p1),
        math.cos(ang) - math.sin(p1) * math.sin(p2),
    )
    return math.degrees(p2), (math.degrees(l2) + 540) % 360 - 180


def angular_diff(a, b):
    """Smallest absolute difference between two bearings, in degrees [0, 180]."""
    d = abs((a - b + 180) % 360 - 180)
    return d


def cross_track_km(center_lat, center_lon, bearing, lat, lon):
    """Perpendicular distance (km) of a point from the line through center
    along `bearing`. Used for the straight-line corridor explorer mode."""
    d13 = haversine_km(center_lat, center_lon, lat, lon) / EARTH_RADIUS_KM
    theta13 = math.radians(bearing_deg(center_lat, center_lon, lat, lon))
    theta12 = math.radians(bearing)
    return abs(math.asin(math.sin(d13) * math.sin(theta13 - theta12))) * EARTH_RADIUS_KM
