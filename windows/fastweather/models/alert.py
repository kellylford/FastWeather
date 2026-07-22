"""Weather alert model (US National Weather Service)."""

from dataclasses import dataclass

# Severity ordering (most severe first) for sorting/display.
SEVERITY_ORDER = {"Extreme": 0, "Severe": 1, "Moderate": 2, "Minor": 3, "Unknown": 4}


@dataclass
class WeatherAlert:
    event: str
    severity: str
    headline: str
    description: str
    instruction: str
    onset: str
    ends: str
    area: str

    @property
    def sort_key(self):
        return SEVERITY_ORDER.get(self.severity, 4)
