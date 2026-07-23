"""Weather Around Me: weather for 8 cardinal directions + center at a radius.

Fetches weather concurrently for the nine points; reverse-geocodes surrounding
place names (serialized/throttled by the geocoding service). Runs on a worker
thread via the FetchManager, so blocking here is fine.
"""

from concurrent.futures import ThreadPoolExecutor

from ..geo import CARDINALS_8, destination_point
from ..models.regional import RegionalTile
from . import geocoding_service, weather_service


def _tile_weather(tile):
    try:
        data = weather_service.fetch_weather(tile.lat, tile.lon, "basic")
        curr = data.get("current", {})
        tile.temp_c = curr.get("temperature_2m")
        tile.weather_code = curr.get("weather_code")
        tile.cloud_cover = curr.get("cloud_cover")
        tile.wind_kmh = curr.get("wind_speed_10m")
        tile.wind_dir = curr.get("wind_direction_10m")
    except Exception as e:  # noqa: BLE001
        tile.error = str(e)
    return tile


def fetch_regional(center_name, center_lat, center_lon, radius_km):
    """Return {'center': RegionalTile, 'tiles': [RegionalTile x8], 'radius_km'}.

    The center keeps the known city name (no reverse geocode); surrounding
    points are reverse-geocoded (cached after first run).
    """
    center = RegionalTile("Center", center_name, center_lat, center_lon, 0.0)
    tiles = []
    for name, bearing in CARDINALS_8:
        lat, lon = destination_point(center_lat, center_lon, bearing, radius_km)
        tiles.append(RegionalTile(name, "", lat, lon, radius_km))

    # Weather concurrently (independent, no rate limit).
    with ThreadPoolExecutor(max_workers=5) as ex:
        list(ex.map(_tile_weather, [center] + tiles))

    # Reverse-geocode surrounding names (serialized + throttled inside service).
    for t in tiles:
        t.name = geocoding_service.reverse_geocode(t.lat, t.lon)

    return {"center": center, "tiles": tiles, "radius_km": radius_km}
