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


_LOCALITY_KEYS = ("city", "town", "village", "hamlet", "municipality", "suburb", "county")


def _locality(addr):
    for k in _LOCALITY_KEYS:
        if addr.get(k):
            return addr[k]
    return ""


def build_match(result, specific=True):
    """Turn a raw Nominatim result into a match dict with a display label.

    When ``specific`` is True and the result is a named place distinct from its
    locality (an airport, university, landmark, address...), the label leads
    with that specific name and appends locality context - mirroring the iOS
    "specific place names" behavior. When False, or for plain localities, the
    label is the familiar "City, State, Country".
    """
    addr = result.get("address", {})
    name = (result.get("namedetails") or {}).get("name") or result.get("name") or ""
    locality = _locality(addr)
    state = addr.get("state", "")
    country = addr.get("country", "")

    if specific and name and name != locality:
        context = ", ".join(p for p in (locality, state, country) if p)
        display = f"{name} - {context}" if context else name
    else:
        display = ", ".join(p for p in (locality or name, state, country) if p)

    if not display:
        display = name or f"{result.get('lat')}, {result.get('lon')}"

    return {
        "display": display,
        "name": name,
        "city": locality,
        "state": state,
        "country": country,
        "kind": result.get("addresstype") or result.get("type") or "",
        "importance": float(result.get("importance") or 0.0),
        "lat": float(result["lat"]),
        "lon": float(result["lon"]),
    }


def geocode(query, specific=True):
    """Return a list of match dicts for a place / city / zip / address query.

    Each match: {display, name, city, state, country, kind, importance, lat, lon}.
    Results are ordered by Nominatim's importance so a genuinely notable place
    (a city, a university, an airport) outranks an obscure road that merely
    shares the query text (Nominatim otherwise boosts exact-name matches).
    """
    params = {
        "q": query, "format": "json", "addressdetails": 1,
        "namedetails": 1, "limit": 8,
    }
    headers = {"User-Agent": USER_AGENT}
    results = http.get_json(NOMINATIM_URL, params=params, headers=headers)
    matches = [build_match(r, specific) for r in results]
    matches.sort(key=lambda m: m["importance"], reverse=True)
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
