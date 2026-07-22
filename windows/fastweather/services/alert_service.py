"""US weather alerts via the National Weather Service (api.weather.gov).

NWS is US-only. Results are cached 5 minutes. A fetch failure raises (so the UI
can show a distinct "couldn't check" state) and must never be presented as
"no alerts". Field values are coerced defensively because NWS returns
inconsistent types (string, array, or null) across alerts.
"""

from ..cache.memory_cache import TTLCache
from ..models.alert import WeatherAlert
from . import http

NWS_ALERTS_URL = "https://api.weather.gov/alerts/active"

_cache = TTLCache(default_ttl=300)  # 5 minutes


def _coerce_str(value):
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return "; ".join(str(v) for v in value if v is not None)
    return str(value)


def fetch_alerts(lat, lon, use_cache=True):
    """Return a severity-sorted list of WeatherAlert for a US coordinate.

    Raises on network/parse failure so callers can distinguish "couldn't check"
    from "no active alerts".
    """
    key = f"{lat:.3f},{lon:.3f}"
    if use_cache:
        cached = _cache.get(key)
        if cached is not None:
            return cached

    data = http.get_json(NWS_ALERTS_URL, params={"point": f"{lat},{lon}"})
    alerts = []
    for feature in data.get("features", []):
        p = feature.get("properties", {})
        alerts.append(WeatherAlert(
            event=_coerce_str(p.get("event")),
            severity=_coerce_str(p.get("severity")) or "Unknown",
            headline=_coerce_str(p.get("headline")),
            description=_coerce_str(p.get("description")),
            instruction=_coerce_str(p.get("instruction")),
            onset=_coerce_str(p.get("onset") or p.get("effective")),
            # NWS: prefer 'ends' over 'expires'
            ends=_coerce_str(p.get("ends") or p.get("expires")),
            area=_coerce_str(p.get("areaDesc")),
        ))
    alerts.sort(key=lambda a: a.sort_key)
    _cache.set(key, alerts)
    return alerts


def has_active_alerts(lat, lon):
    """Best-effort boolean for badging; returns None if the check failed."""
    try:
        return len(fetch_alerts(lat, lon)) > 0
    except Exception:
        return None
