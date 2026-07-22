"""Shared NWS (api.weather.gov) alert feature parsing.

Handles NWS's inconsistent field types, prefers `ends` over `expires` (clamped
to never precede `onset`), labels bare zone areas with their state via UGC
prefixes (skipping marine zones), and promotes Unknown-severity Air Quality
alerts to Moderate so they aren't stranded below every filter.
"""

from ..models.alert import WeatherAlert, _parse_dt

STATE_POSTAL = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID",
    "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS",
    "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK",
    "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV",
    "WI", "WY", "DC", "PR", "VI", "GU", "AS", "MP",
}


def coerce_str(value, joiner="; "):
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return joiner.join(str(v) for v in value if v is not None)
    return str(value)


def _labeled_area(area, geocode):
    """Append state postal codes (from UGC) to a bare area description."""
    if not area or "," in area:
        return area
    ugc = (geocode or {}).get("UGC") or []
    if isinstance(ugc, str):
        ugc = [ugc]
    states = []
    for code in ugc:
        if isinstance(code, str) and len(code) >= 2:
            st = code[:2].upper()
            if st in STATE_POSTAL and st not in states:
                states.append(st)
    if states:
        return f"{area}, {'/'.join(states)}"
    return area


def _clamp_end(ends, onset):
    e, o = _parse_dt(ends), _parse_dt(onset)
    if e and o and e < o:
        return onset
    return ends


def _normalize_severity(severity, event):
    sev = (severity or "Unknown").capitalize()
    if sev not in ("Extreme", "Severe", "Moderate", "Minor", "Unknown"):
        sev = "Unknown"
    if sev == "Unknown" and "air quality" in (event or "").lower():
        return "Moderate"
    return sev


def parse_feature(feature):
    """Return a WeatherAlert from an NWS GeoJSON feature."""
    p = feature.get("properties", {})
    event = coerce_str(p.get("event"))
    onset = coerce_str(p.get("onset") or p.get("effective"))
    ends = _clamp_end(coerce_str(p.get("ends") or p.get("expires")), onset)
    return WeatherAlert(
        event=event,
        severity=_normalize_severity(coerce_str(p.get("severity")), event),
        headline=coerce_str(p.get("headline"), joiner=" "),
        description=coerce_str(p.get("description"), joiner="\n"),
        instruction=coerce_str(p.get("instruction"), joiner="\n"),
        onset=onset,
        ends=ends,
        area=_labeled_area(coerce_str(p.get("areaDesc"), joiner=", "), p.get("geocode", {})),
        id=coerce_str(p.get("id")),
        source="NWS",
        details_url="https://www.weather.gov",
    )
