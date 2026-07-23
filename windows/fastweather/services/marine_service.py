"""Open-Meteo Marine API (waves, swell, currents, sea temperature)."""

from ..constants import OPEN_METEO_MARINE_URL
from . import http

# Fields for the standalone Marine sheet.
_MARINE_CURRENT = (
    "wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,"
    "swell_wave_period,wind_wave_height,ocean_current_velocity,ocean_current_direction,"
    "sea_surface_temperature"
)


def fetch_marine(lat, lon, hourly_keys=None, current=None):
    params = {"latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 1}
    if current:
        params["current"] = current
    if hourly_keys:
        params["hourly"] = ",".join(hourly_keys)
    return http.get_json(OPEN_METEO_MARINE_URL, params=params)


def fetch_marine_summary(lat, lon):
    """Current marine conditions for the Marine sheet."""
    return fetch_marine(lat, lon, current=_MARINE_CURRENT)
