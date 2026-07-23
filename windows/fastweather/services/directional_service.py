"""Directional Explorer: browse cached cities along a bearing from a center.

Two modes mirror iOS: an arc (fan of a given angular width) or a straight-line
corridor (cities within a perpendicular distance of the center line). Returns
cities sorted by distance, with weather fetched concurrently for the top N.
"""

from concurrent.futures import ThreadPoolExecutor

from ..geo import angular_diff, bearing_deg, cross_track_km, haversine_km
from . import weather_service

ARC_WIDTHS = {"Narrow": 10, "Standard": 22.5, "Medium": 45, "Wide": 90}
CORRIDOR_WIDTHS_KM = {"Narrow": 16, "Standard": 32, "Medium": 48, "Wide": 80}


def find_cities(center_lat, center_lon, bearing, all_cities, mode="arc",
                width="Standard", max_distance_km=560, limit=20):
    """Return up to `limit` city dicts along the bearing, nearest first.

    Each result adds distance_km and bearing_deg to the source city dict.
    """
    results = []
    for c in all_cities:
        dist = haversine_km(center_lat, center_lon, c["lat"], c["lon"])
        if dist < 5 or dist > max_distance_km:
            continue
        cb = bearing_deg(center_lat, center_lon, c["lat"], c["lon"])
        if mode == "corridor":
            if angular_diff(cb, bearing) > 90:  # must be ahead, not behind
                continue
            half = CORRIDOR_WIDTHS_KM.get(width, 32)
            if cross_track_km(center_lat, center_lon, bearing, c["lat"], c["lon"]) > half:
                continue
        else:  # arc
            half = ARC_WIDTHS.get(width, 22.5) / 2
            if angular_diff(cb, bearing) > half:
                continue
        item = dict(c)
        item["distance_km"] = dist
        item["bearing_deg"] = cb
        results.append(item)

    results.sort(key=lambda x: x["distance_km"])
    results = results[:limit]

    def add_weather(item):
        try:
            data = weather_service.fetch_weather(item["lat"], item["lon"], "basic")
            curr = data.get("current", {})
            item["temp_c"] = curr.get("temperature_2m")
            item["weather_code"] = curr.get("weather_code")
            item["cloud_cover"] = curr.get("cloud_cover")
        except Exception as e:  # noqa: BLE001
            item["error"] = str(e)
        return item

    if results:
        with ThreadPoolExecutor(max_workers=5) as ex:
            list(ex.map(add_weather, results))
    return results
