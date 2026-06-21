#!/usr/bin/env python3
"""
QuickRadar
==========

A small data-gathering script for a screen-reader-friendly weather app.

Given a US zipcode it will:
  1. Geocode the zipcode to lat/lon (zippopotam.us, free, no API key).
  2. Find the nearest NWS radar station (api.weather.gov, free, no API key).
  3. Download the latest base-reflectivity radar image for that station.
  4. Send the image to a local Ollama vision model and ask for a detailed,
     objective description of what the radar shows.
  5. Fetch the latest observation from the nearest NWS weather station
     (current conditions tuned to mirror what the radar shows "right now").
  6. Write both the AI radar description and the current conditions to a
     text file.

This is intended as a research / data-gathering activity to evaluate how well
vision-language models can communicate radar imagery to users who cannot see
the image (e.g. screen-reader users).

Usage:
    python quickradar.py 60601
    python quickradar.py 90210 --model gemma4:31b-cloud --output report.txt --keep-image

Requirements:
    pip install -r requirements.txt
    A running Ollama server (default http://localhost:11434) with a vision model
    pulled, e.g.:  ollama pull gemma4:31b-cloud
"""

import argparse
import base64
import math
import sys
from datetime import datetime
from pathlib import Path

import requests

# Prefer the official `ollama` package if installed; fall back to raw REST calls.
try:
    import ollama  # type: ignore
    HAS_OLLAMA_PKG = True
except ImportError:
    HAS_OLLAMA_PKG = False


# A descriptive User-Agent is required by the NWS API.
NWS_HEADERS = {
    "Accept": "application/geo+json",
    "User-Agent": "QuickRadar/1.0 (weather-app research; contact: local)",
}

# ---------------------------------------------------------------------------
# Geocoding
# ---------------------------------------------------------------------------
def geocode_zipcode(zipcode: str) -> dict:
    """Return lat/lon/city/state for a US zipcode via zippopotam.us (free)."""
    url = f"https://api.zippopotam.us/us/{zipcode}"
    resp = requests.get(url, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    if not data or "places" not in data or not data["places"]:
        raise ValueError(f"Could not geocode zipcode {zipcode!r}")
    place = data["places"][0]
    return {
        "lat": float(place["latitude"]),
        "lon": float(place["longitude"]),
        "city": place["place name"],
        "state": place["state"],
        "state_abbrev": data.get("state abbreviation", ""),
        "country": data.get("country", ""),
    }


# ---------------------------------------------------------------------------
# Geometry helper
# ---------------------------------------------------------------------------
def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in km between two lat/lon points."""
    R = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlam / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


# ---------------------------------------------------------------------------
# Radar station lookup + image download
# ---------------------------------------------------------------------------
def find_nearest_radar_station(lat: float, lon: float) -> dict:
    """Query the NWS radar stations list and return the nearest NEXRAD station.

    Only considers WSR-88D NEXRAD stations (IDs starting with 'K') since those
    are the ones with RIDGE image products. TDWR and other radar types (IDs
    starting with 'T', 'R', etc.) do not have standard RIDGE images.
    """
    url = "https://api.weather.gov/radar/stations"
    resp = requests.get(url, headers=NWS_HEADERS, timeout=20)
    resp.raise_for_status()
    features = resp.json().get("features", [])
    if not features:
        raise ValueError("NWS returned no radar stations")

    best, best_dist = None, None
    for st in features:
        coords = st.get("geometry", {}).get("coordinates")
        if not coords or len(coords) < 2:
            continue
        props = st.get("properties", {})
        sid = props.get("id", "").upper()
        # Only NEXRAD WSR-88D stations (K-prefixed) have RIDGE images.
        if not sid.startswith("K"):
            continue
        st_lon, st_lat = coords[0], coords[1]
        d = haversine_km(lat, lon, st_lat, st_lon)
        if best_dist is None or d < best_dist:
            best_dist = d
            best = {
                "id": sid,
                "name": props.get("name", "Unknown"),
                "lat": st_lat,
                "lon": st_lon,
                "distance_km": d,
            }
    if best is None:
        raise ValueError("Could not find a usable NEXRAD (K-prefixed) radar station")
    return best


def download_radar_image(station_id: str, out_path: Path) -> str:
    """Download the latest base-reflectivity radar image for a station.

    Tries several known NWS RIDGE URL patterns and returns the URL that worked.
    Raises RuntimeError if none succeed.
    """
    sid = station_id.upper()
    candidates = [
        f"https://radar.weather.gov/ridge/standard/{sid}_0.gif",
        f"https://radar.weather.gov/ridge/standard/{sid}_0.png",
        f"https://radar.weather.gov/ridge/standard/{sid.lower()}_0.gif",
        f"https://radar.weather.gov/ridge/standard/{sid.lower()}_0.png",
    ]
    headers = {"User-Agent": NWS_HEADERS["User-Agent"]}
    last_status = None
    for url in candidates:
        try:
            resp = requests.get(url, headers=headers, timeout=20)
            last_status = resp.status_code
            # A real radar image is well over 1KB; tiny responses are error pages.
            if resp.status_code == 200 and len(resp.content) > 1000:
                out_path.write_bytes(resp.content)
                return url
        except requests.RequestException:
            continue
    raise RuntimeError(
        f"Could not download radar image for station {sid} "
        f"(last HTTP status: {last_status}). The NWS RIDGE image for this "
        f"station may be temporarily unavailable."
    )


def crop_radar_to_location(
    image_path: Path,
    station_lat: float,
    station_lon: float,
    user_lat: float,
    user_lon: float,
    radius_km: float = 75.0,
) -> Path:
    """Crop a radar image to a box centered on the user's location.

    NWS RIDGE single-station images are 600x550 pixels covering the full
    radar range (~460 km). The radar station is at the image center. This
    function calculates where the user falls in the image, crops a square
    box of (2 * radius_km) around that point, and upscales it back to the
    original dimensions so the vision model sees a zoomed-in view.

    Returns the path to the cropped image (overwrites the input file).
    Requires Pillow (PIL).
    """
    from PIL import Image

    img = Image.open(image_path)
    W, H = img.size
    cx, cy = W // 2, H // 2

    # Approximate scale: NEXRAD range ~230 km radius, image ~460 km across.
    scale = 460.0 / W  # km per pixel

    # Offset of user from radar station (equirectangular, fine for <500 km).
    lat_km_per_deg = 111.0
    lon_km_per_deg = 111.0 * math.cos(math.radians(station_lat))
    dlat_km = (user_lat - station_lat) * lat_km_per_deg
    dlon_km = (user_lon - station_lon) * lon_km_per_deg

    # Image coords: right = east (+x), up = north (-y).
    user_px = cx + dlon_km / scale
    user_py = cy - dlat_km / scale

    crop_px = int(radius_km / scale)
    left = max(0, int(user_px - crop_px))
    top = max(0, int(user_py - crop_px))
    right = min(W, int(user_px + crop_px))
    bottom = min(H, int(user_py + crop_px))

    cropped = img.crop((left, top, right, bottom))
    # Upscale back to original size for consistent model input.
    cropped = cropped.resize((W, H), Image.LANCZOS)
    cropped.save(image_path)
    return image_path


# ---------------------------------------------------------------------------
# Current conditions (tuned to match what a radar image shows: "right now")
# ---------------------------------------------------------------------------
def _c_to_f(c) -> float:
    """Convert a Celsius value (which may be None) to Fahrenheit, or None."""
    if c is None:
        return None
    return round(c * 9 / 5 + 32, 1)


def _kmh_to_mph(kmh) -> float:
    """Convert km/h to mph, or None."""
    if kmh is None:
        return None
    return round(kmh * 0.621371, 1)


def _pa_to_inhg(pa) -> float:
    """Convert Pascals to inches of mercury, or None."""
    if pa is None:
        return None
    return round(pa / 3386.39, 2)


def _m_to_mi(m) -> float:
    """Convert meters to miles, or None."""
    if m is None:
        return None
    return round(m / 1609.344, 1)


def _round_or_none(val, ndigits=1):
    """Round a value to ndigits, or return None if val is None.

    When ndigits is 0, returns an int (no trailing .0).
    """
    if val is None:
        return None
    if ndigits == 0:
        return int(round(val))
    return round(val, ndigits)


def _deg_to_compass(deg) -> str:
    """Convert a wind direction in degrees to a 16-point compass label."""
    if deg is None:
        return ""
    dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
    return dirs[int((deg + 11.25) / 22.5) % 16]


def get_current_conditions(lat: float, lon: float) -> dict:
    """Fetch the latest observation from the nearest NWS station.

    This is tuned to mirror what a radar image shows — the weather *right now*
    — rather than a multi-day forecast. Returns a dict with:
      station_id, station_name, observation_time, text_description,
      temperature_f, dewpoint_f, humidity, wind_speed_mph, wind_gust_mph,
      wind_direction_deg, wind_direction, pressure_inhg, visibility_mi,
      cloud_layers, present_weather, precipitation_last_hour_mm,
      precipitation_last_3h_mm, precipitation_last_6h_mm,
      short_forecast (the current/next forecast period's short text)
    """
    points_url = f"https://api.weather.gov/points/{lat:.4f},{lon:.4f}"
    resp = requests.get(points_url, headers=NWS_HEADERS, timeout=20)
    resp.raise_for_status()
    props = resp.json().get("properties", {})

    # --- Nearest observation station + latest observation ---------------
    stations_url = props.get("observationStations")
    if not stations_url:
        raise ValueError("NWS points response did not include observationStations URL")

    resp = requests.get(stations_url, headers=NWS_HEADERS, timeout=20)
    resp.raise_for_status()
    station_features = resp.json().get("features", [])
    if not station_features:
        raise ValueError("No observation stations returned for this point")

    station_props = station_features[0].get("properties", {})
    station_id = station_props.get("stationIdentifier", "Unknown")
    station_name = station_props.get("name", "Unknown")

    # Fetch the latest observation from that station.
    obs_url = f"https://api.weather.gov/stations/{station_id}/observations/latest"
    resp = requests.get(obs_url, headers=NWS_HEADERS, timeout=20)
    resp.raise_for_status()
    obs = resp.json().get("properties", {})

    def _val(field):
        v = obs.get(field)
        if v is None:
            return None
        if isinstance(v, dict):
            return v.get("value")
        return v

    cloud_layers = []
    for cl in obs.get("cloudLayers", []) or []:
        base = cl.get("base", {})
        cloud_layers.append({
            "amount": cl.get("amount", ""),
            "base_m": base.get("value"),
            "base_ft": round(base.get("value", 0) * 3.28084) if base.get("value") else None,
        })

    present_weather = []
    for pw in obs.get("presentWeather", []) or []:
        present_weather.append({
            "intensity": pw.get("intensity", ""),
            "modifier": pw.get("modifier", ""),
            "weather": pw.get("weather", ""),
            "obscuration": pw.get("obscuration", ""),
        })

    conditions = {
        "station_id": station_id,
        "station_name": station_name,
        "observation_time": obs.get("timestamp", ""),
        "text_description": obs.get("textDescription", ""),
        "temperature_f": _c_to_f(_val("temperature")),
        "dewpoint_f": _c_to_f(_val("dewpoint")),
        "humidity": _round_or_none(_val("relativeHumidity"), 0),
        "wind_speed_mph": _kmh_to_mph(_val("windSpeed")),
        "wind_gust_mph": _kmh_to_mph(_val("windGust")),
        "wind_direction_deg": _val("windDirection"),
        "wind_direction": _deg_to_compass(_val("windDirection")),
        "pressure_inhg": _pa_to_inhg(_val("barometricPressure")),
        "visibility_mi": _m_to_mi(_val("visibility")),
        "cloud_layers": cloud_layers,
        "present_weather": present_weather,
        "precipitation_last_hour_mm": _val("precipitationLastHour"),
        "precipitation_last_3h_mm": _val("precipitationLast3Hours"),
        "precipitation_last_6h_mm": _val("precipitationLast6Hours"),
        "max_temp_24h_f": _c_to_f(_val("maxTemperatureLast24Hours")),
        "min_temp_24h_f": _c_to_f(_val("minTemperatureLast24Hours")),
    }

    # --- Current/next forecast period (short summary for "now") ---------
    forecast_url = props.get("forecast")
    short_forecast = ""
    if forecast_url:
        try:
            resp = requests.get(forecast_url, headers=NWS_HEADERS, timeout=20)
            resp.raise_for_status()
            periods = resp.json().get("properties", {}).get("periods", [])
            if periods:
                # The first period is "now" (e.g. "Tonight" or "Today").
                p = periods[0]
                short_forecast = (
                    f"{p.get('name', '')}: {p.get('shortForecast', '')} "
                    f"({p.get('temperature', '?')}{p.get('temperatureUnit', '')})"
                )
        except Exception:
            pass
    conditions["short_forecast"] = short_forecast

    return conditions


# ---------------------------------------------------------------------------
# Configuration file (prompt.txt)
# ---------------------------------------------------------------------------
DEFAULT_CONFIG_PATH = "prompt.txt"

# Built-in fallback prompt used when no config file is present.
DEFAULT_RADAR_PROMPT = (
    "You are looking at a weather radar image. Please provide a detailed, "
    "objective description suitable for someone who cannot see the image "
    "(for example, a screen-reader user). Describe:\n"
    "  - The overall coverage area and what region the radar appears to show.\n"
    "  - The presence and location of any precipitation, and its intensity "
    "(light, moderate, heavy).\n"
    "  - The colors or color bands visible and what they typically indicate "
    "on a radar (e.g. green=light, yellow=moderate, red=heavy).\n"
    "  - Any storm cells, lines of storms, or areas of rotation if discernible.\n"
    "  - The general shape and movement of precipitation features if you can "
    "infer it.\n"
    "  - Whether the image appears mostly clear or active.\n"
    "Be specific and factual. Do not speculate beyond what is visible in the "
    "image. If something is unclear, say so."
)


def load_config(config_path: Path) -> dict:
    """Read zipcode, model, and prompt from the config file.

    The file format is simple:
      - Lines starting with '#' are comments and ignored.
      - 'zipcode: <value>' sets the zipcode.
      - 'model: <value>' sets the Ollama model.
      - Everything after a line that is exactly 'prompt:' (optionally with
        trailing whitespace) is captured verbatim as the prompt text, up to
        the end of the file.

    Returns a dict with keys 'zipcode', 'model', 'prompt'. Any field not
    found in the file is set to None.
    """
    cfg = {"zipcode": None, "model": None, "prompt": None}
    if not config_path.exists():
        return cfg

    text = config_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Find the 'prompt:' marker line (a line whose stripped value == 'prompt:')
    prompt_marker_idx = None
    for i, line in enumerate(lines):
        if line.strip().lower() == "prompt:":
            prompt_marker_idx = i
            break

    # Parse the key/value lines before the prompt marker.
    end = prompt_marker_idx if prompt_marker_idx is not None else len(lines)
    for line in lines[:end]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = key.strip().lower()
        value = value.strip()
        if key == "zipcode":
            cfg["zipcode"] = value
        elif key == "model":
            cfg["model"] = value

    # Capture everything after the 'prompt:' marker as the prompt text.
    if prompt_marker_idx is not None:
        prompt_lines = lines[prompt_marker_idx + 1:]
        # Strip leading/trailing blank lines but preserve internal formatting.
        while prompt_lines and not prompt_lines[0].strip():
            prompt_lines.pop(0)
        while prompt_lines and not prompt_lines[-1].strip():
            prompt_lines.pop()
        cfg["prompt"] = "\n".join(prompt_lines)

    return cfg


# ---------------------------------------------------------------------------
# Ollama image description
# ---------------------------------------------------------------------------
def _extract_token_info(response) -> dict:
    """Pull the token-count fields Ollama includes in non-streaming responses."""
    info = {
        "prompt_eval_count": response.get("prompt_eval_count"),
        "eval_count": response.get("eval_count"),
        "total_tokens": None,
        "eval_duration_ns": response.get("eval_duration"),
        "prompt_eval_duration_ns": response.get("prompt_eval_duration"),
    }
    if info["prompt_eval_count"] is not None and info["eval_count"] is not None:
        info["total_tokens"] = info["prompt_eval_count"] + info["eval_count"]
    return info


def _image_to_png_b64(image_path: Path) -> str:
    """Read an image file and return it as a base64-encoded PNG string.

    GIF files are converted to PNG because many vision models reject GIF input.
    PNG files are passed through as-is.
    """
    try:
        from PIL import Image
        import io
        img = Image.open(image_path)
        buf = io.BytesIO()
        img.convert("RGB").save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("utf-8")
    except ImportError:
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")


def describe_radar_with_ollama(
    image_path: Path,
    model: str,
    ollama_url: str = "http://localhost:11434",
    prompt: str = DEFAULT_RADAR_PROMPT,
) -> tuple:
    """Send the radar image to Ollama.

    Returns a tuple of (description_text, token_info) where token_info is a dict
    with prompt_eval_count, eval_count, total_tokens, and eval_duration_ns if
    available (Ollama exposes these in the non-streaming chat response).
    """
    img_b64 = _image_to_png_b64(image_path)

    token_info = {}

    if HAS_OLLAMA_PKG:
        # Configure the client host if a non-default URL was given.
        client_kwargs = {}
        if ollama_url != "http://localhost:11434":
            client_kwargs["host"] = ollama_url
        client = ollama.Client(**client_kwargs) if client_kwargs else ollama
        response = client.chat(
            model=model,
            messages=[{"role": "user", "content": prompt, "images": [img_b64]}],
        )
        description = response["message"]["content"]
        token_info = _extract_token_info(response)
    else:
        # Fallback: talk to the Ollama REST API directly.
        url = ollama_url.rstrip("/") + "/api/chat"
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt, "images": [img_b64]}],
            "stream": False,
        }
        resp = requests.post(url, json=payload, timeout=300)
        resp.raise_for_status()
        data = resp.json()
        description = data["message"]["content"]
        token_info = _extract_token_info(data)

    return description, token_info


# ---------------------------------------------------------------------------
# Token-count logging / formatting
# ---------------------------------------------------------------------------
def _log_token_count(token_info: dict) -> None:
    """Print a human-readable summary of Ollama token usage to stdout."""
    if not token_info:
        print("      -> token counts not available in Ollama response")
        return
    prompt = token_info.get("prompt_eval_count")
    resp = token_info.get("eval_count")
    total = token_info.get("total_tokens")
    print("      -> token counts:")
    if prompt is not None:
        print(f"         prompt tokens : {prompt}")
    if resp is not None:
        print(f"         output tokens : {resp}")
    if total is not None:
        print(f"         total tokens  : {total}")
    eval_ns = token_info.get("eval_duration_ns")
    if eval_ns:
        print(f"         gen duration  : {eval_ns / 1e9:.2f} s")


def _format_token_info_for_report(token_info: dict) -> str:
    """Format token usage as a multi-line string for the text report."""
    if not token_info:
        return "[token counts not available in Ollama response]"
    lines = []
    prompt = token_info.get("prompt_eval_count")
    resp = token_info.get("eval_count")
    total = token_info.get("total_tokens")
    if prompt is not None:
        lines.append(f"  Prompt tokens : {prompt}")
    if resp is not None:
        lines.append(f"  Output tokens : {resp}")
    if total is not None:
        lines.append(f"  Total tokens  : {total}")
    eval_ns = token_info.get("eval_duration_ns")
    if eval_ns:
        lines.append(f"  Gen duration  : {eval_ns / 1e9:.2f} s")
    return "\n".join(lines) if lines else "[token counts not available]"


# ---------------------------------------------------------------------------
# Report assembly
# ---------------------------------------------------------------------------
def _fmt(val, suffix=""):
    """Format a possibly-None value with an optional suffix."""
    if val is None:
        return "N/A"
    return f"{val}{suffix}"


def _format_current_conditions(conditions: dict) -> list:
    """Format the current-conditions dict as a list of report lines."""
    lines = []
    if not conditions:
        lines.append("[No current conditions data available]")
        lines.append("")
        return lines

    lines.append(f"Observation station: {conditions.get('station_id', '?')} - "
                 f"{conditions.get('station_name', '?')}")
    lines.append(f"Observation time:    {conditions.get('observation_time', 'N/A')}")
    lines.append(f"Conditions:           {conditions.get('text_description', 'N/A')}")
    lines.append("")

    lines.append("Temperature:         "
                 f"{_fmt(conditions.get('temperature_f'), ' F')}")
    lines.append("Dewpoint:            "
                 f"{_fmt(conditions.get('dewpoint_f'), ' F')}")
    lines.append("Humidity:            "
                 f"{_fmt(conditions.get('humidity'), '%')}")
    lines.append("Wind:                "
                 f"{_fmt(conditions.get('wind_speed_mph'), ' mph')} "
                 f"{conditions.get('wind_direction', '')} "
                 f"({conditions.get('wind_direction_deg', 'N/A')} deg)")
    lines.append("Wind gust:           "
                 f"{_fmt(conditions.get('wind_gust_mph'), ' mph')}")
    lines.append("Pressure:            "
                 f"{_fmt(conditions.get('pressure_inhg'), ' inHg')}")
    lines.append("Visibility:          "
                 f"{_fmt(conditions.get('visibility_mi'), ' mi')}")
    lines.append("")

    # Cloud layers
    clouds = conditions.get("cloud_layers", [])
    if clouds:
        lines.append("Cloud layers:")
        for cl in clouds:
            base_ft = cl.get("base_ft")
            lines.append(f"  {cl.get('amount', '?')}"
                         + (f" at {base_ft} ft" if base_ft else ""))
    else:
        lines.append("Cloud layers:       none reported")
    lines.append("")

    # Present weather (intensity + weather type, e.g. "light rain")
    pw = conditions.get("present_weather", [])
    if pw:
        lines.append("Present weather:")
        for w in pw:
            parts = [w.get("intensity", ""), w.get("weather", "")]
            desc = " ".join(p for p in parts if p)
            if w.get("obscuration"):
                desc += f" (obscuration: {w['obscuration']})"
            lines.append(f"  {desc or '(unknown)'}")
    else:
        lines.append("Present weather:     none reported")
    lines.append("")

    # Precipitation — directly comparable to radar reflectivity
    lines.append("Precipitation (recent):")
    lines.append(f"  Last hour:   {_fmt(conditions.get('precipitation_last_hour_mm'), ' mm')}")
    lines.append(f"  Last 3 hrs:  {_fmt(conditions.get('precipitation_last_3h_mm'), ' mm')}")
    lines.append(f"  Last 6 hrs:  {_fmt(conditions.get('precipitation_last_6h_mm'), ' mm')}")
    lines.append("")

    lines.append("Temperature range (last 24h):")
    lines.append(f"  High: {_fmt(conditions.get('max_temp_24h_f'), ' F')}")
    lines.append(f"  Low:  {_fmt(conditions.get('min_temp_24h_f'), ' F')}")
    lines.append("")

    sf = conditions.get("short_forecast", "")
    if sf:
        lines.append(f"Current forecast period: {sf}")
        lines.append("")

    return lines


def build_report(
    zipcode,
    geo,
    station,
    img_url,
    description,
    conditions,
    image_path,
    model_name,
    token_info=None,
) -> str:
    sep = "=" * 70
    lines = [
        sep,
        "QUICKRADAR REPORT",
        sep,
        "",
        f"Zipcode:         {zipcode}",
        f"Location:        {geo['city']}, {geo['state']} ({geo['state_abbrev']})",
        f"Coordinates:     {geo['lat']}, {geo['lon']}",
        f"Radar station:   {station['id']} - {station['name']}",
        f"Station distance: {station['distance_km']:.1f} km from location",
        f"Radar image URL: {img_url}",
        f"Image file:      {image_path.name} ({image_path.stat().st_size} bytes)",
        f"Ollama model:    {model_name}",
        f"Generated:       {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "-" * 70,
        "RADAR IMAGE DESCRIPTION (via Ollama)",
        "-" * 70,
        "",
        description.strip(),
        "",
        "-" * 70,
        "OLLAMA TOKEN USAGE",
        "-" * 70,
        "",
        _format_token_info_for_report(token_info or {}),
        "",
        "-" * 70,
        "CURRENT CONDITIONS (NWS api.weather.gov — nearest station)",
        "-" * 70,
        "",
    ]
    lines += _format_current_conditions(conditions)
    lines += [sep, "END OF REPORT", sep]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download a radar image for a US zipcode, get an AI "
        "description via Ollama, and fetch current conditions from the "
        "nearest NWS station. Outputs a combined text report. Reads "
        "default config from prompt.txt (zipcode, model, prompt) if "
        "present; CLI args override."
    )
    parser.add_argument("zipcode", nargs="?", default=None,
                        help="US zipcode, e.g. 60601. If omitted, read from "
                        "prompt.txt (or use --config).")
    parser.add_argument("--model", default=None,
                        help="Ollama vision model to use. Overrides prompt.txt.")
    parser.add_argument("--config", default=DEFAULT_CONFIG_PATH,
                        help=f"Config file path (default: {DEFAULT_CONFIG_PATH})")
    parser.add_argument("--ollama-url", default="http://localhost:11434",
                        help="Ollama server URL (default: http://localhost:11434)")
    parser.add_argument("--output", "-o", default=None,
                        help="Output text file path (default: weather_<zipcode>.txt)")
    parser.add_argument("--no-keep-image", action="store_true",
                        help="Delete the downloaded radar image after the "
                        "report is written (images are kept by default)")
    parser.add_argument("--zoom", type=float, default=None,
                        help="Crop the radar image to a box of this radius "
                        "(in km) around the user's location, then upscale. "
                        "E.g. --zoom 75 shows a 150km x 150km area centered "
                        "on the zipcode. Default: no zoom (full radar range).")
    args = parser.parse_args()

    # Load config from file (zipcode, model, prompt) ----------------------
    config_path = Path(args.config)
    cfg = load_config(config_path)
    if config_path.exists():
        print(f"Loaded config from: {config_path.resolve()}")

    # Resolve effective values: CLI arg > config file > built-in default
    zipcode = args.zipcode or cfg["zipcode"]
    model = args.model or cfg["model"] or "gemma4:31b-cloud"
    radar_prompt = cfg["prompt"] or DEFAULT_RADAR_PROMPT

    if not zipcode:
        parser.error(
            "No zipcode specified. Provide it as an argument or in the "
            f"config file ({args.config})."
        )

    # 1. Geocode the zipcode ------------------------------------------------
    print(f"[1/5] Geocoding zipcode {zipcode} ...")
    try:
        geo = geocode_zipcode(zipcode)
    except Exception as e:
        print(f"  ERROR geocoding: {e}", file=sys.stderr)
        return 1
    print(f"      -> {geo['city']}, {geo['state']} ({geo['lat']}, {geo['lon']})")

    # 2. Find nearest radar station ----------------------------------------
    print("[2/5] Finding nearest NWS radar station ...")
    try:
        station = find_nearest_radar_station(geo["lat"], geo["lon"])
    except Exception as e:
        print(f"  ERROR finding radar station: {e}", file=sys.stderr)
        return 1
    print(f"      -> {station['id']} ({station['name']}), "
          f"{station['distance_km']:.1f} km away")

    # 3. Download the radar image ------------------------------------------
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    img_path = Path(f"radar_{zipcode}_{station['id']}_{run_stamp}.gif")
    print(f"[3/5] Downloading radar image for station {station['id']} ...")
    try:
        img_url = download_radar_image(station["id"], img_path)
    except Exception as e:
        print(f"  ERROR downloading radar image: {e}", file=sys.stderr)
        return 1
    print(f"      -> saved {img_path.name} ({img_path.stat().st_size} bytes)")

    # Optionally crop/zoom the image to the user's location ---------------
    if args.zoom:
        try:
            crop_radar_to_location(
                img_path, station["lat"], station["lon"],
                geo["lat"], geo["lon"], radius_km=args.zoom,
            )
            print(f"      -> cropped to {args.zoom} km radius around location "
                  f"({img_path.stat().st_size} bytes after crop)")
        except ImportError:
            print("      -> WARNING: --zoom requires Pillow; skipping crop "
                  "(pip install Pillow)", file=sys.stderr)
        except Exception as e:
            print(f"      -> WARNING: zoom crop failed: {e}; using full image",
                  file=sys.stderr)

    # 4. Ask Ollama to describe the image ----------------------------------
    print(f"[4/5] Sending radar image to Ollama (model: {model}) ...")
    token_info = {}
    try:
        description, token_info = describe_radar_with_ollama(
            img_path, model, args.ollama_url, radar_prompt
        )
        print("      -> description received")
        _log_token_count(token_info)
    except Exception as e:
        description = f"[ERROR getting description from Ollama: {e}]"
        print(f"  ERROR from Ollama: {e}", file=sys.stderr)
        print("  (Continuing so the forecast is still written to the report.)")

    # 5. Fetch current conditions (tuned to match "right now" radar) ------
    print("[5/5] Fetching current conditions from nearest NWS station ...")
    try:
        conditions = get_current_conditions(geo["lat"], geo["lon"])
        print(f"      -> station {conditions.get('station_id', '?')} "
              f"({conditions.get('station_name', '?')}), "
              f"obs at {conditions.get('observation_time', 'N/A')}")
    except Exception as e:
        conditions = {}
        print(f"  ERROR fetching current conditions: {e}", file=sys.stderr)

    # Assemble and write the report ----------------------------------------
    if args.output:
        out_path = Path(args.output)
    else:
        out_path = Path(f"weather_{zipcode}_{run_stamp}.txt")
    report = build_report(zipcode, geo, station, img_url, description,
                          conditions, img_path, model, token_info)
    out_path.write_text(report, encoding="utf-8")
    print(f"\nReport written to: {out_path.resolve()}")

    # Optionally clean up the image ---------------------------------------
    if args.no_keep_image:
        try:
            img_path.unlink()
            print(f"Removed radar image {img_path.name} "
                  f"(images are kept by default; use --no-keep-image to delete)")
        except OSError:
            pass
    else:
        print(f"Radar image kept at: {img_path.resolve()}")

    return 0


if __name__ == "__main__":
    sys.exit(main())