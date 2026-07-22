"""Precipitation nowcast via Open-Meteo minutely_15.

Windows uses the Open-Meteo 15-minute NWP path only (WeatherKit's minute
nowcast is Apple-only). Builds a next-hour timeline, an intensity label per
step, and a plain-language status (precip now / starts in N min / none).
"""

from datetime import datetime

from ..constants import OPEN_METEO_API_URL
from ..models.radar import RadarData, TimelinePoint, intensity_label
from . import http

_STEP_MINUTES = 15
_WINDOW_MINUTES = 60


def _parse(t):
    try:
        return datetime.strptime(t, "%Y-%m-%dT%H:%M")
    except Exception:
        return None


def fetch_nowcast(lat, lon):
    """Return a RadarData nowcast for the next hour."""
    data = http.get_json(OPEN_METEO_API_URL, params={
        "latitude": lat, "longitude": lon, "timezone": "auto",
        "current": "precipitation", "minutely_15": "precipitation",
        "forecast_days": 1,
    })
    m15 = data.get("minutely_15", {})
    times = m15.get("time", [])
    precip = m15.get("precipitation", [])
    current_time = data.get("current", {}).get("time")

    # Locate the current 15-minute slot (last slot at or before now).
    start = 0
    if current_time and times:
        for i, t in enumerate(times):
            if t <= current_time:
                start = i
            else:
                break

    steps = _WINDOW_MINUTES // _STEP_MINUTES
    timeline = []
    starts_in = None
    stops_in = None
    precipitating_now = False

    for step in range(steps + 1):
        idx = start + step
        if idx >= len(precip):
            break
        mm = precip[idx] or 0.0
        minutes = step * _STEP_MINUTES
        lab = intensity_label(mm)
        timeline.append(TimelinePoint(minutes, mm, lab))
        if step == 0 and mm > 0:
            precipitating_now = True
        if mm > 0 and starts_in is None:
            starts_in = minutes
        if precipitating_now and mm <= 0 and stops_in is None:
            stops_in = minutes

    # Status text.
    if precipitating_now:
        if stops_in:
            status = f"Precipitation now; easing in about {stops_in} min."
        else:
            status = "Precipitation now; continuing through the next hour."
    elif starts_in is not None:
        status = f"Precipitation likely starting in about {starts_in} min."
    else:
        status = "No precipitation expected in the next hour."

    return RadarData(status=status, starts_in_minutes=starts_in,
                     stops_in_minutes=stops_in, timeline=timeline)
