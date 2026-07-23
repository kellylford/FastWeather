"""Alert Browser: national alert digests by region/authority.

Fetches every active alert for a region (not a single point), so the UI can
filter by severity/hazard and group by event. Sources: NWS (United States) and
Environment Canada (ECCC). Results and counts are cached 5 minutes.
"""

from ..cache.memory_cache import TTLCache
from ..models.alert import WeatherAlert
from . import http, nws

NWS_ACTIVE_URL = "https://api.weather.gov/alerts/active"
ECCC_URL = "https://api.weather.gc.ca/collections/weather-alerts/items"

# Region catalog (order shown in the picker).
REGIONS = [
    {"id": "us", "name": "United States (NWS)", "source": "NWS"},
    {"id": "ca", "name": "Canada (Environment Canada)", "source": "ECCC"},
]

_alerts_cache = TTLCache(default_ttl=300)
_count_cache = TTLCache(default_ttl=300)


def region_by_id(region_id):
    for r in REGIONS:
        if r["id"] == region_id:
            return r
    return None


# -- NWS ---------------------------------------------------------------------
def _fetch_nws():
    # NWS rejects a `limit` param with HTTP 400; use status=actual only.
    data = http.get_json(NWS_ACTIVE_URL, params={"status": "actual"})
    alerts = [nws.parse_feature(f) for f in data.get("features", [])]
    return [a for a in alerts if a.ends and not a.is_expired()]


# -- ECCC (Canada) -----------------------------------------------------------
def _eccc_severity(p):
    colour = (p.get("risk_colour_en") or "").strip().lower()
    if colour in ("red",):
        return "Extreme"
    if colour in ("orange",):
        return "Severe"
    if colour in ("yellow",):
        return "Moderate"
    if colour in ("grey", "gray", "green"):
        return "Minor"
    atype = (p.get("alert_type") or "").strip().lower()
    if atype == "warning":
        return "Severe"
    if atype == "watch":
        return "Moderate"
    return "Minor"  # advisory / statement / other


def _eccc_alert(feature):
    p = feature.get("properties", {})
    event = (p.get("alert_name_en") or p.get("alert_short_name_en") or "Alert").strip()
    event = event[:1].upper() + event[1:]
    area = (p.get("feature_name_en") or "").strip()
    prov = (p.get("province") or "").strip()
    if area and prov and prov not in area:
        area = f"{area}, {prov}"
    ends = p.get("event_end_datetime") or p.get("expiration_datetime") or ""
    onset = p.get("validity_datetime") or p.get("publication_datetime") or ""
    return WeatherAlert(
        event=event,
        severity=_eccc_severity(p),
        headline=event,
        description=(p.get("alert_text_en") or "").strip(),
        instruction="",
        onset=onset,
        ends=ends,
        area=area,
        id=str(p.get("id") or p.get("feature_id") or ""),
        source="Environment Canada",
        details_url="https://weather.gc.ca/warnings/index_e.html",
    )


def _fetch_eccc():
    data = http.get_json(ECCC_URL, params={"f": "json", "limit": 500})
    alerts = []
    for feature in data.get("features", []):
        p = feature.get("properties", {})
        status = (p.get("status_en") or p.get("display_status") or "").lower()
        if "ended" in status or "expired" in status:
            continue
        a = _eccc_alert(feature)
        if a.ends and a.is_expired():
            continue
        alerts.append(a)
    return alerts


# -- public API --------------------------------------------------------------
def fetch_region_alerts(region_id, use_cache=True):
    """Return all active alerts for a region. Raises on failure."""
    if use_cache:
        cached = _alerts_cache.get(region_id)
        if cached is not None:
            return cached
    if region_id == "us":
        alerts = _fetch_nws()
    elif region_id == "ca":
        alerts = _fetch_eccc()
    else:
        raise ValueError(f"Unknown region: {region_id}")
    _alerts_cache.set(region_id, alerts)
    return alerts


def alert_count(region_id):
    """Active-alert count for a region, or None if the check failed."""
    cached = _count_cache.get(region_id)
    if cached is not None:
        return cached
    try:
        n = len(fetch_region_alerts(region_id))
    except Exception:
        return None
    _count_cache.set(region_id, n)
    return n
