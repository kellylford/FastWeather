"""Models for historical weather (Open-Meteo archive)."""

from dataclasses import dataclass


@dataclass
class HistoricalDay:
    date: str                 # YYYY-MM-DD
    temp_max: float = None
    temp_min: float = None
    precip_sum: float = None
    snowfall_sum: float = None
    wind_max: float = None
    weather_code: int = None
    error: str = None
