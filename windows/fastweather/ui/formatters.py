"""Unit-aware value formatting.

Extracted verbatim from the monolith's format_* helpers so output strings are
byte-identical. Reads the current unit selection from AppSettings live.
"""

from ..constants import KMH_TO_MPH, MM_TO_INCHES

_CARDINALS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


def degrees_to_cardinal(degrees):
    index = round(degrees / 45) % 8
    return _CARDINALS[index]


class Formatter:
    """Formats temperature / wind / precipitation per the user's unit settings."""

    def __init__(self, settings):
        self.settings = settings

    @property
    def _units(self):
        return self.settings["units"]

    def temperature(self, temp_c):
        if self._units["temperature"] == "C":
            return f"{temp_c:.1f}°C"
        temp_f = (temp_c * 9 / 5) + 32
        return f"{temp_f:.1f}°F"

    def temperature_short(self, temp_c):
        if self._units["temperature"] == "C":
            return f"{temp_c:.0f}°C"
        temp_f = (temp_c * 9 / 5) + 32
        return f"{temp_f:.0f}°F"

    def wind_speed(self, wind_kmh):
        if self._units["wind_speed"] == "km/h":
            return f"{wind_kmh:.1f} km/h"
        wind_mph = wind_kmh * KMH_TO_MPH
        return f"{wind_mph:.1f} mph"

    def precipitation(self, precip_mm):
        if self._units["precipitation"] == "mm":
            return f"{precip_mm:.1f}mm"
        precip_in = precip_mm * MM_TO_INCHES
        return f'{precip_in:.2f}"'

    # convenience passthrough so callers can use one object everywhere
    cardinal = staticmethod(degrees_to_cardinal)
