"""My Data parameter catalog.

A registry of Open-Meteo parameters the user can add to a custom section,
organized into categories. Each parameter names its API endpoint
(forecast / marine / air_quality), a formatting ``kind`` (temperature / wind /
precip / distance / pressure map to unit-aware formatting; ``raw`` uses the
``unit`` suffix as-is), and a plain-English explanation.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class MyDataParameter:
    key: str            # Open-Meteo hourly variable name
    name: str           # display name
    category: str
    endpoint: str       # "forecast" | "marine" | "air_quality"
    kind: str           # temperature|wind|precip|distance|pressure|raw
    unit: str = ""      # suffix for kind == "raw"
    explanation: str = ""


# Ordered catalog. Not exhaustive of Open-Meteo, but broad coverage across
# every category the iOS app exposes.
CATALOG = [
    # Temperature (multi-altitude)
    MyDataParameter("temperature_2m", "Temperature (2 m)", "Temperature", "forecast", "temperature", "", "Air temperature at 2 meters."),
    MyDataParameter("temperature_80m", "Temperature (80 m)", "Temperature", "forecast", "temperature", "", "Air temperature at 80 meters."),
    MyDataParameter("temperature_120m", "Temperature (120 m)", "Temperature", "forecast", "temperature", "", "Air temperature at 120 meters."),
    MyDataParameter("apparent_temperature", "Apparent Temperature", "Temperature", "forecast", "temperature", "", "How hot/cold it feels."),
    MyDataParameter("dewpoint_2m", "Dew Point", "Temperature", "forecast", "temperature", "", "Temperature at which dew forms."),

    # Humidity & Moisture
    MyDataParameter("relative_humidity_2m", "Relative Humidity", "Humidity & Moisture", "forecast", "raw", "%", "Humidity relative to saturation."),
    MyDataParameter("vapour_pressure_deficit", "Vapour Pressure Deficit", "Humidity & Moisture", "forecast", "raw", " kPa", "Dryness of the air; drives evaporation."),

    # Wind (multi-altitude)
    MyDataParameter("wind_speed_10m", "Wind Speed (10 m)", "Wind", "forecast", "wind", "", "Wind speed at 10 meters."),
    MyDataParameter("wind_speed_80m", "Wind Speed (80 m)", "Wind", "forecast", "wind", "", "Wind speed at 80 meters."),
    MyDataParameter("wind_speed_120m", "Wind Speed (120 m)", "Wind", "forecast", "wind", "", "Wind speed at 120 meters."),
    MyDataParameter("wind_gusts_10m", "Wind Gusts (10 m)", "Wind", "forecast", "wind", "", "Peak gust speed at 10 meters."),

    # Precipitation
    MyDataParameter("precipitation", "Precipitation", "Precipitation", "forecast", "precip", "", "Total liquid-equivalent precipitation."),
    MyDataParameter("rain", "Rain", "Precipitation", "forecast", "precip", "", "Liquid rain amount."),
    MyDataParameter("showers", "Showers", "Precipitation", "forecast", "precip", "", "Convective shower amount."),
    MyDataParameter("snowfall", "Snowfall", "Precipitation", "forecast", "precip", "", "Snowfall amount."),
    MyDataParameter("precipitation_probability", "Precip Probability", "Precipitation", "forecast", "raw", "%", "Chance of precipitation."),

    # Pressure
    MyDataParameter("pressure_msl", "Pressure (MSL)", "Pressure", "forecast", "pressure", "", "Mean sea-level pressure."),
    MyDataParameter("surface_pressure", "Surface Pressure", "Pressure", "forecast", "pressure", "", "Pressure at the surface."),

    # Clouds & Visibility
    MyDataParameter("cloud_cover", "Cloud Cover", "Clouds & Visibility", "forecast", "raw", "%", "Total cloud cover."),
    MyDataParameter("cloud_cover_low", "Cloud Cover (Low)", "Clouds & Visibility", "forecast", "raw", "%", "Low-level cloud cover."),
    MyDataParameter("cloud_cover_mid", "Cloud Cover (Mid)", "Clouds & Visibility", "forecast", "raw", "%", "Mid-level cloud cover."),
    MyDataParameter("cloud_cover_high", "Cloud Cover (High)", "Clouds & Visibility", "forecast", "raw", "%", "High-level cloud cover."),
    MyDataParameter("visibility", "Visibility", "Clouds & Visibility", "forecast", "distance", "", "Horizontal visibility."),

    # Solar & UV
    MyDataParameter("uv_index", "UV Index", "Solar & UV", "forecast", "raw", "", "Ultraviolet radiation index."),
    MyDataParameter("shortwave_radiation", "Shortwave Radiation", "Solar & UV", "forecast", "raw", " W/m²", "Incoming solar radiation."),
    MyDataParameter("direct_radiation", "Direct Radiation", "Solar & UV", "forecast", "raw", " W/m²", "Direct-beam solar radiation."),
    MyDataParameter("diffuse_radiation", "Diffuse Radiation", "Solar & UV", "forecast", "raw", " W/m²", "Scattered/diffuse solar radiation."),

    # Soil
    MyDataParameter("soil_temperature_0cm", "Soil Temp (0 cm)", "Soil", "forecast", "temperature", "", "Soil temperature at the surface."),
    MyDataParameter("soil_temperature_6cm", "Soil Temp (6 cm)", "Soil", "forecast", "temperature", "", "Soil temperature at 6 cm depth."),
    MyDataParameter("soil_moisture_0_to_1cm", "Soil Moisture (0-1 cm)", "Soil", "forecast", "raw", " m³/m³", "Water content near the surface."),
    MyDataParameter("soil_moisture_3_to_9cm", "Soil Moisture (3-9 cm)", "Soil", "forecast", "raw", " m³/m³", "Water content at 3-9 cm depth."),

    # Atmosphere
    MyDataParameter("cape", "CAPE", "Atmosphere", "forecast", "raw", " J/kg", "Convective energy; thunderstorm potential."),
    MyDataParameter("freezing_level_height", "Freezing Level Height", "Atmosphere", "forecast", "raw", " m", "Altitude of the 0°C level."),
    MyDataParameter("evapotranspiration", "Evapotranspiration", "Atmosphere", "forecast", "precip", "", "Water lost to the atmosphere."),

    # Marine & Ocean
    MyDataParameter("wave_height", "Wave Height", "Marine & Ocean", "marine", "raw", " m", "Combined sea + swell wave height."),
    MyDataParameter("wave_direction", "Wave Direction", "Marine & Ocean", "marine", "raw", "°", "Mean wave direction."),
    MyDataParameter("wave_period", "Wave Period", "Marine & Ocean", "marine", "raw", " s", "Time between wave crests."),
    MyDataParameter("swell_wave_height", "Swell Height", "Marine & Ocean", "marine", "raw", " m", "Swell (distant) wave height."),
    MyDataParameter("swell_wave_period", "Swell Period", "Marine & Ocean", "marine", "raw", " s", "Swell wave period."),
    MyDataParameter("sea_surface_temperature", "Sea Surface Temp", "Marine & Ocean", "marine", "temperature", "", "Ocean surface temperature."),
    MyDataParameter("ocean_current_velocity", "Ocean Current Velocity", "Marine & Ocean", "marine", "raw", " km/h", "Speed of ocean surface current."),

    # Air Quality
    MyDataParameter("pm2_5", "PM2.5", "Air Quality", "air_quality", "raw", " µg/m³", "Fine particulate matter."),
    MyDataParameter("pm10", "PM10", "Air Quality", "air_quality", "raw", " µg/m³", "Coarse particulate matter."),
    MyDataParameter("carbon_monoxide", "Carbon Monoxide", "Air Quality", "air_quality", "raw", " µg/m³", "CO concentration."),
    MyDataParameter("nitrogen_dioxide", "Nitrogen Dioxide", "Air Quality", "air_quality", "raw", " µg/m³", "NO₂ concentration."),
    MyDataParameter("sulphur_dioxide", "Sulphur Dioxide", "Air Quality", "air_quality", "raw", " µg/m³", "SO₂ concentration."),
    MyDataParameter("ozone", "Ozone", "Air Quality", "air_quality", "raw", " µg/m³", "Ground-level ozone."),
    MyDataParameter("european_aqi", "European AQI", "Air Quality", "air_quality", "raw", "", "European air-quality index."),
    MyDataParameter("us_aqi", "US AQI", "Air Quality", "air_quality", "raw", "", "US air-quality index."),

    # Pollen
    MyDataParameter("alder_pollen", "Alder Pollen", "Pollen", "air_quality", "raw", " grains/m³", "Alder pollen concentration."),
    MyDataParameter("birch_pollen", "Birch Pollen", "Pollen", "air_quality", "raw", " grains/m³", "Birch pollen concentration."),
    MyDataParameter("grass_pollen", "Grass Pollen", "Pollen", "air_quality", "raw", " grains/m³", "Grass pollen concentration."),
    MyDataParameter("ragweed_pollen", "Ragweed Pollen", "Pollen", "air_quality", "raw", " grains/m³", "Ragweed pollen concentration."),
]

CATALOG_BY_KEY = {p.key: p for p in CATALOG}


def format_value(param, value, fmt):
    """Format a My Data value using the parameter's kind and a Formatter."""
    if value is None:
        return "N/A"
    kind = param.kind
    if kind == "temperature":
        return fmt.temperature(value)
    if kind == "wind":
        return fmt.wind_speed(value)
    if kind == "precip":
        return fmt.precipitation(value)
    if kind == "distance":
        return fmt.distance(value)
    if kind == "pressure":
        return fmt.pressure(value)
    # raw
    if isinstance(value, float):
        text = f"{value:.2f}".rstrip("0").rstrip(".")
    else:
        text = str(value)
    return f"{text}{param.unit}"


def categories():
    """Ordered list of category names as they appear in the catalog."""
    seen = []
    for p in CATALOG:
        if p.category not in seen:
            seen.append(p.category)
    return seen


def params_in(category):
    return [p for p in CATALOG if p.category == category]
