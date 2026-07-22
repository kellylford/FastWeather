"""Nominatim (OpenStreetMap) forward geocoding.

Pure data: given a user query, returns a list of match dicts. Behavior is
preserved verbatim from the original monolith's GeocodingThread.
"""

from ..constants import NOMINATIM_URL, USER_AGENT
from . import http


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
