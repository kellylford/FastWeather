"""Locale-aware default units, seeded from the user's Windows region.

Applied only on first run (when no config.json exists yet); after that the
user's saved unit choices always win. Mirrors the iOS app seeding units from
locale, and in particular picks the right wind unit per country — wind is not
simply metric/imperial: many countries report it in meters per second, others
in km/h, a few in mph.

The country sets are a curated, easily-adjustable mapping; when the region
can't be determined the caller keeps the existing (US) defaults.
"""

# Temperature / precipitation / pressure in US customary.
_FAHRENHEIT = {"US", "BS", "BZ", "KY", "PW", "FM", "MH"}
_INCH_PRECIP = {"US"}
_INHG_PRESSURE = {"US"}
_MMHG_PRESSURE = {"RU"}          # Russia reports pressure in mmHg
_MILES_DISTANCE = {"US", "GB"}   # US + UK use miles for distance

# Wind: the interesting one.
_MPH_WIND = {"US", "GB"}
_MS_WIND = {  # national services / public reports commonly use meters/second
    "NO", "SE", "FI", "DK", "IS",          # Nordics
    "EE", "LV", "LT",                      # Baltics
    "RU", "UA", "BY",                      # former USSR
    "CN", "JP", "KR",                      # East Asia
    "NL",                                  # KNMI
}
# everything else metric -> km/h


def detect_country():
    """Return the user's ISO-3166 alpha-2 country code (Windows), or None."""
    try:
        import ctypes
        buf = ctypes.create_unicode_buffer(16)
        # GetUserDefaultGeoName: the user's Country/Region (Win10 1709+).
        if ctypes.windll.kernel32.GetUserDefaultGeoName(buf, len(buf)) > 0 and buf.value:
            return buf.value.strip().upper()[:2]
    except Exception:
        pass
    try:
        import ctypes
        buf = ctypes.create_unicode_buffer(85)
        if ctypes.windll.kernel32.GetUserDefaultLocaleName(buf, len(buf)) and "-" in buf.value:
            return buf.value.split("-")[-1].strip().upper()[:2]
    except Exception:
        pass
    return None


def default_units_for_country(code):
    """Return a units dict for an ISO country code (pure; testable)."""
    code = (code or "").upper()
    if code in _MPH_WIND:
        wind = "mph"
    elif code in _MS_WIND:
        wind = "m/s"
    else:
        wind = "km/h"
    if code in _INHG_PRESSURE:
        pressure = "inHg"
    elif code in _MMHG_PRESSURE:
        pressure = "mmHg"
    else:
        pressure = "hPa"
    return {
        "temperature": "F" if code in _FAHRENHEIT else "C",
        "wind_speed": wind,
        "precipitation": "in" if code in _INCH_PRECIP else "mm",
        "distance": "mi" if code in _MILES_DISTANCE else "km",
        "pressure": pressure,
    }


def locale_default_units():
    """Units for the current Windows region, or None if it can't be determined."""
    code = detect_country()
    if not code:
        return None
    return default_units_for_country(code)
