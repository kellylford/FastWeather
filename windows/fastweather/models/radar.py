"""Models for the precipitation nowcast (Expected Precipitation)."""

from dataclasses import dataclass, field


@dataclass
class TimelinePoint:
    minutes_from_now: int
    mm: float
    intensity: str


@dataclass
class RadarData:
    status: str                              # human summary
    starts_in_minutes: int = None            # None if no precip in window
    stops_in_minutes: int = None
    timeline: list = field(default_factory=list)  # list[TimelinePoint]


def intensity_label(mm_per_15min):
    """Classify a 15-minute precipitation amount into an intensity band."""
    if mm_per_15min is None or mm_per_15min <= 0.0:
        return "None"
    rate = mm_per_15min * 4  # mm per hour
    if rate < 2.5:
        return "Light"
    if rate < 7.6:
        return "Moderate"
    return "Heavy"
