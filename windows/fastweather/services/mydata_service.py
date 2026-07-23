"""My Data: fetch current values for a user-selected set of parameters.

Groups parameters by API endpoint (forecast / marine / air_quality), issues one
request per endpoint (hourly), and extracts the value for the current hour.
Each endpoint failure is isolated so a marine outage doesn't hide forecast data.
"""

from ..constants import OPEN_METEO_API_URL
from . import air_quality_service, http, marine_service


def _extract(data, keys, ref_time, results, errors, group):
    hourly = data.get("hourly", {})
    times = hourly.get("time", [])
    idx = 0
    if ref_time and ref_time in times:
        idx = times.index(ref_time)
    for k in keys:
        arr = hourly.get(k)
        results[k] = arr[idx] if arr and idx < len(arr) else None


def fetch_mydata(lat, lon, params):
    """Return (values: {key: value|None}, errors: {group: message})."""
    results = {}
    errors = {}
    ref_time = None

    forecast_keys = [p.key for p in params if p.endpoint == "forecast"]
    marine_keys = [p.key for p in params if p.endpoint == "marine"]
    aq_keys = [p.key for p in params if p.endpoint == "air_quality"]

    if forecast_keys:
        try:
            data = http.get_json(OPEN_METEO_API_URL, params={
                "latitude": lat, "longitude": lon, "timezone": "auto",
                "current": "temperature_2m", "hourly": ",".join(forecast_keys),
                "forecast_days": 1,
            })
            ref_time = data.get("current", {}).get("time")
            _extract(data, forecast_keys, ref_time, results, errors, "forecast")
        except Exception as e:  # noqa: BLE001
            errors["forecast"] = str(e)
            for k in forecast_keys:
                results.setdefault(k, None)

    if marine_keys:
        try:
            data = marine_service.fetch_marine(lat, lon, hourly_keys=marine_keys)
            _extract(data, marine_keys, ref_time, results, errors, "marine")
        except Exception as e:  # noqa: BLE001
            errors["marine"] = str(e)
            for k in marine_keys:
                results.setdefault(k, None)

    if aq_keys:
        try:
            data = air_quality_service.fetch_air_quality(lat, lon, hourly_keys=aq_keys)
            _extract(data, aq_keys, ref_time, results, errors, "air_quality")
        except Exception as e:  # noqa: BLE001
            errors["air_quality"] = str(e)
            for k in aq_keys:
                results.setdefault(k, None)

    return results, errors
