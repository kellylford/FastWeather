"""Models for Weather Around Me (regional directional weather)."""

from dataclasses import dataclass


@dataclass
class RegionalTile:
    direction: str          # "Center", "N", "NE", ...
    name: str               # reverse-geocoded place name
    lat: float
    lon: float
    distance_km: float
    temp_c: float = None
    weather_code: int = None
    cloud_cover: float = None
    wind_kmh: float = None
    wind_dir: float = None
    error: str = None
