"""Weather alert model, hazard classification, severity filtering, and digest.

Ports the iOS alert browser's contract: severity ordering, exclusive severity
filters, hazard classification (keyword order is load-bearing), and the
severity|event grouping used to collapse many area-level products into one row.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone

# Severity ordering (lower = more critical), matching iOS AlertSeverity.sortOrder.
SEVERITY_ORDER = {"Extreme": 0, "Severe": 1, "Moderate": 2, "Minor": 3, "Unknown": 4}
SEVERITY_ALL = ["Extreme", "Severe", "Moderate", "Minor", "Unknown"]

# Exclusive severity filters (NOT a ">= threshold"): each shows only that level.
SEVERITY_FILTERS = ["Extreme", "Severe", "Moderate", "All"]

# Hazard families in display order (iOS HazardType order).
HAZARD_ORDER = [
    "Storms", "Tropical", "Flooding", "Rain", "Heat", "Winter", "Wind",
    "Fire", "Fog", "Marine & Coastal", "Air Quality", "Other",
]


def classify_hazard(event):
    """Classify an event name into a hazard family. First keyword match wins;
    the order here is deliberate (winter before heat, tropical before storms,
    a bare 'storm' falls to wind) and mirrors iOS HazardType.classify."""
    e = (event or "").lower()

    def has(*kw):
        return any(k in e for k in kw)

    if has("hurricane", "tropical", "typhoon", "storm surge"):
        return "Tropical"
    if has("tornado", "thunderstorm", "severe weather", "special weather statement", "lightning"):
        return "Storms"
    if has("flood", "hydrologic", "seiche"):
        return "Flooding"
    if has("winter", "snow", "blizzard", "ice storm", "freez", "frost", "wind chill",
            "sleet", "cold", "avalanche", "low temperature", "low-temperature", "icy", "glaze"):
        return "Winter"
    if has("fire", "red flag"):
        return "Fire"
    if has("air quality", "air stagnation", "ozone", "dust", "ashfall", "smoke"):
        return "Air Quality"
    if has("heat", "high temperature", "high-temperature", "hot", "heatwave", "warm"):
        return "Heat"
    if has("fog"):
        return "Fog"
    if has("rain", "downpour", "shower", "precipitation"):
        return "Rain"
    if has("wind", "gale", "storm"):
        return "Wind"
    if has("marine", "small craft", "seas", "surf", "rip current", "beach",
            "coastal", "tsunami", "low water", "ashore"):
        return "Marine & Coastal"
    return "Other"


def severity_filter_includes(filter_value, severity):
    """Exclusive: 'All' passes everything; otherwise only the exact severity."""
    if filter_value == "All":
        return True
    return severity == filter_value


def _parse_dt(s):
    if not s:
        return None
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


@dataclass
class WeatherAlert:
    event: str
    severity: str
    headline: str
    description: str
    instruction: str
    onset: str
    ends: str            # effective end (ends-or-expires), used for expiry
    area: str
    id: str = ""
    source: str = "NWS"
    details_url: str = ""

    @property
    def sort_key(self):
        return SEVERITY_ORDER.get(self.severity, 4)

    @property
    def hazard(self):
        return classify_hazard(self.event)

    @property
    def ends_dt(self):
        return _parse_dt(self.ends)

    def is_expired(self, now=None):
        end = self.ends_dt
        if end is None:
            return False  # unknown end -> keep (never hide as expired)
        now = now or datetime.now(timezone.utc)
        return now > end


@dataclass
class AlertDigestGroup:
    event: str
    severity: str
    alerts: list = field(default_factory=list)

    @property
    def count(self):
        return len(self.alerts)

    @property
    def sort_key(self):
        return SEVERITY_ORDER.get(self.severity, 4)

    @property
    def soonest_expires(self):
        ends = [a.ends_dt for a in self.alerts if a.ends_dt]
        return min(ends) if ends else None


def build_digest(alerts, severity_filter="All", hazard_filter=None):
    """Collapse alerts into groups keyed by severity|event.

    Filters by (exclusive) severity and optional hazard family, groups the
    remaining alerts, and sorts groups by severity, then count desc, then event.
    """
    scoped = [a for a in alerts
              if severity_filter_includes(severity_filter, a.severity)
              and (hazard_filter is None or a.hazard == hazard_filter)]

    groups = {}
    for a in scoped:
        key = f"{a.severity}|{a.event}"
        groups.setdefault(key, AlertDigestGroup(a.event, a.severity)).alerts.append(a)

    result = list(groups.values())
    for g in result:
        g.alerts.sort(key=lambda x: (x.ends_dt is None, x.ends_dt or datetime.max.replace(tzinfo=timezone.utc)))
    result.sort(key=lambda g: (g.sort_key, -g.count, g.event.lower()))
    return result


def severity_counts(alerts):
    """Histogram of alerts by severity (all levels, including zeros)."""
    counts = {s: 0 for s in SEVERITY_ALL}
    for a in alerts:
        counts[a.severity] = counts.get(a.severity, 0) + 1
    return counts


def hazard_counts(alerts):
    counts = {}
    for a in alerts:
        counts[a.hazard] = counts.get(a.hazard, 0) + 1
    return counts
