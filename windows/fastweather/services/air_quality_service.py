"""Open-Meteo Air Quality API (particulates, gases, AQI, pollen)."""

from ..constants import OPEN_METEO_AIR_QUALITY_URL
from . import http

_AQ_CURRENT = (
    "pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,"
    "european_aqi,us_aqi"
)


def fetch_air_quality(lat, lon, hourly_keys=None, current=None):
    params = {"latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 1}
    if current:
        params["current"] = current
    if hourly_keys:
        params["hourly"] = ",".join(hourly_keys)
    return http.get_json(OPEN_METEO_AIR_QUALITY_URL, params=params)


def fetch_air_quality_summary(lat, lon):
    """Current air-quality values for a quick summary."""
    return fetch_air_quality(lat, lon, current=_AQ_CURRENT)
