"""Open-Meteo forecast fetching (current / hourly / daily).

Pure data: given coordinates and a detail level, returns the parsed API JSON.
Parameter sets are preserved verbatim from the original monolith.
"""

from ..constants import OPEN_METEO_API_URL
from . import http

_CURRENT_FIELDS = (
    "temperature_2m,relative_humidity_2m,apparent_temperature,dewpoint_2m,is_day,"
    "precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,"
    "surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility"
)

_FULL_HOURLY_FIELDS = (
    "temperature_2m,apparent_temperature,relative_humidity_2m,dewpoint_2m,precipitation,"
    "precipitation_probability,rain,showers,snowfall,snow_depth,weathercode,pressure_msl,"
    "surface_pressure,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,visibility,"
    "evapotranspiration,et0_fao_evapotranspiration,vapor_pressure_deficit,windspeed_10m,"
    "winddirection_10m,windgusts_10m,uv_index,uv_index_clear_sky,is_day,cape,"
    "freezing_level_height,soil_temperature_0cm"
)

_FULL_DAILY_FIELDS = (
    "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,"
    "apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,"
    "uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,"
    "snowfall_sum,precipitation_hours,precipitation_probability_max,windspeed_10m_max,"
    "windgusts_10m_max,winddirection_10m_dominant,shortwave_radiation_sum,"
    "et0_fao_evapotranspiration"
)


def fetch_weather(lat, lon, detail="basic", forecast_days=16):
    """Fetch forecast data for a coordinate. Returns parsed JSON dict.

    detail="basic": lightweight (list summary). detail="full": complete
    hourly + daily forecast for the detailed view.
    """
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": _CURRENT_FIELDS,
        "timezone": "auto",
    }
    if detail == "full":
        params["hourly"] = _FULL_HOURLY_FIELDS
        params["daily"] = _FULL_DAILY_FIELDS
        params["forecast_days"] = forecast_days
    else:
        params["hourly"] = "cloudcover"
        params["daily"] = "temperature_2m_max,temperature_2m_min"
        params["forecast_days"] = 1

    return http.get_json(OPEN_METEO_API_URL, params=params)
