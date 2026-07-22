"""Weather value helpers: WMO weather-code descriptions and cloud-cover buckets.

The WMO code table was defined in the original monolith but not used for
display (the code fell back to cloud-cover buckets). It is preserved here so
Phase 1 can wire it into condition text without behavior change in Phase 0.
"""

# WMO Weather interpretation codes (WW)
WEATHER_CODE_DESCRIPTION = {
    0: "Clear sky",
    1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Depositing rime fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    56: "Light freezing drizzle", 57: "Dense freezing drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    66: "Light freezing rain", 67: "Heavy freezing rain",
    71: "Slight snow fall", 73: "Moderate snow fall", 75: "Heavy snow fall",
    77: "Snow grains",
    80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail",
}


def describe_weather_code(code):
    """Return a human description for a WMO weather code, or None if unknown."""
    return WEATHER_CODE_DESCRIPTION.get(code)


def describe_cloud_cover(cc):
    """Bucket a cloud-cover percentage into a description (matches monolith)."""
    if cc is None:
        return None
    if cc <= 12:
        return "clear"
    elif cc <= 37:
        return "mostly clear"
    elif cc <= 62:
        return "partly cloudy"
    elif cc <= 87:
        return "mostly cloudy"
    return "cloudy"
