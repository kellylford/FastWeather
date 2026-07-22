"""Nominatim (OpenStreetMap) forward and reverse geocoding.

Forward geocoding is preserved verbatim from the original monolith. Reverse
geocoding (added for Weather Around Me) is throttled to honor Nominatim's
~1 req/sec policy and disk-cached permanently (place names don't change).
"""

import threading
import time

from ..constants import NOMINATIM_URL, USER_AGENT
from ..cache.disk_cache import DiskCache
from . import http

NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"

# Serialize + throttle reverse-geocode calls across worker threads.
_reverse_lock = threading.Lock()
_last_reverse_at = [0.0]
_reverse_cache = None  # DiskCache built lazily (avoids filesystem work at import)


def _cache():
    global _reverse_cache
    if _reverse_cache is None:
        _reverse_cache = DiskCache("geocode", max_age=None)  # permanent
    return _reverse_cache


def geocode(query):
    """Return a list of match dicts for a city name / zip query.

    Each match: {display, city, state, country, lat, lon}.
    """
    params = {"q": query, "format": "json", "addressdetails": 1, "limit": 5}
    headers = {"User-Agent": USER_AGENT}
    results = http.get_json(NOMINATIM_URL, params=params, headers=headers)

    matches = []
    for r in results:
        address = r.get("address", {})
        city_name = (
            address.get("city")
            or address.get("town")
            or address.get("village")
            or query
        )
        state = address.get("state", "")
        country = address.get("country", "")
        display_parts = [p for p in [city_name, state, country] if p]
        matches.append({
            "display": ", ".join(display_parts),
            "city": city_name,
            "state": state,
            "country": country,
            "lat": float(r["lat"]),
            "lon": float(r["lon"]),
        })
    return matches


def reverse_geocode(lat, lon):
    """Return a short place name for a coordinate (throttled, disk-cached)."""
    key = f"{lat:.4f},{lon:.4f}"
    cached = _cache().get(key)
    if cached is not None:
        return cached

    with _reverse_lock:
        # honor ~1 req/sec
        elapsed = time.monotonic() - _last_reverse_at[0]
        if elapsed < 1.1:
            time.sleep(1.1 - elapsed)
        try:
            params = {"lat": lat, "lon": lon, "format": "json", "zoom": 10,
                      "addressdetails": 1}
            headers = {"User-Agent": USER_AGENT}
            data = http.get_json(NOMINATIM_REVERSE_URL, params=params, headers=headers)
        except Exception:
            data = None
        finally:
            _last_reverse_at[0] = time.monotonic()

    name = _format_place(data, lat, lon)
    if data is not None:
        _cache().set(key, name)
    return name


def _format_place(data, lat, lon):
    if not data:
        return f"{lat:.2f}, {lon:.2f}"
    addr = data.get("address", {})
    place = (addr.get("city") or addr.get("town") or addr.get("village")
             or addr.get("hamlet") or addr.get("county")
             or addr.get("state") or "")
    region = addr.get("state", "")
    parts = [p for p in [place, region] if p and p != place]
    if place and region and region != place:
        return f"{place}, {region}"
    if place:
        return place
    return data.get("display_name", f"{lat:.2f}, {lon:.2f}").split(",")[0]
