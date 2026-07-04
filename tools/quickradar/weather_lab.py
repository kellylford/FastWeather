#!/usr/bin/env python3
"""
weather_lab.py — Weather Images experimentation lab.

Goal: explore what's *possible* for a blind user when you go beyond a single
radar image. For one location, fetch a whole suite of FREE NOAA/NWS weather
images (local radar, regional satellite, national mosaic, forecast maps,
local meteogram), describe each one with AI using a prompt tailored to that
image type, sonify the local radar into stereo audio, and emit an accessible
HTML report you can read top-to-bottom with VoiceOver.

Nothing here ships. It's a learning bench. Every image source is free and
needs no API key.

Usage:
    python3 weather_lab.py 53703                  # by US zip
    python3 weather_lab.py "Madison, WI"          # by place name
    python3 weather_lab.py 53703 --ai fm          # Foundation Models (default)
    python3 weather_lab.py 53703 --ai ollama      # local Ollama vision model
    python3 weather_lab.py 53703 --ai both        # run both, compare
    python3 weather_lab.py 53703 --ai none         # just fetch + sonify, no AI
    python3 weather_lab.py 53703 --only radar_local,goes_ir
    python3 weather_lab.py 53703 --no-audio        # skip the radar sonification too

Output: runs/<timestamp>_<place>/  with images/, audio/, descriptions, data.json,
and report.html (open this).
"""

import argparse
import base64
import datetime as dt
import json
import math
import os
import struct
import subprocess
import sys
import tempfile
import time
import wave
from html import escape
from pathlib import Path

import requests

try:
    from PIL import Image
    import io
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False

HERE = Path(__file__).resolve().parent
NWS_HEADERS = {"User-Agent": "WeatherFast-Lab/1.0 (kelly@theideaplace.net)"}
TIMEOUT = 30


# ──────────────────────────────────────────────────────────────────────────
# Location resolution
# ──────────────────────────────────────────────────────────────────────────

def resolve_location(arg):
    """Return dict with lat, lon, label, zip. Accepts a US zip or a place name."""
    arg = arg.strip()
    if arg.isdigit() and len(arg) == 5:
        r = requests.get(f"https://api.zippopotam.us/us/{arg}", timeout=TIMEOUT)
        r.raise_for_status()
        d = r.json()
        place = d["places"][0]
        return {
            "lat": float(place["latitude"]),
            "lon": float(place["longitude"]),
            "label": f'{place["place name"]}, {place["state abbreviation"]}',
            "zip": arg,
        }
    # place name → Nominatim
    r = requests.get(
        "https://nominatim.openstreetmap.org/search",
        params={"q": arg, "format": "json", "countrycodes": "us", "limit": 1},
        headers=NWS_HEADERS, timeout=TIMEOUT)
    r.raise_for_status()
    hits = r.json()
    if not hits:
        raise SystemExit(f"Could not geocode '{arg}'")
    h = hits[0]
    return {"lat": float(h["lat"]), "lon": float(h["lon"]),
            "label": arg, "zip": None}


def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


_stations = None

def nearest_nexrad(lat, lon):
    global _stations
    if _stations is None:
        r = requests.get("https://api.weather.gov/radar/stations",
                         headers=NWS_HEADERS, timeout=TIMEOUT)
        r.raise_for_status()
        _stations = r.json().get("features", [])
    best, best_d = None, 1e9
    for st in _stations:
        sid = st["properties"].get("id", "")
        rda = st["properties"].get("rda", {})
        # station coords live in geometry
        geom = st.get("geometry") or {}
        coords = geom.get("coordinates")
        if not coords or len(coords) < 2:
            continue
        slon, slat = coords[0], coords[1]
        d = haversine_km(lat, lon, slat, slon)
        if d < best_d and sid:
            best_d = d
            best = {"id": sid, "name": st["properties"].get("name", sid),
                    "lat": slat, "lon": slon, "dist_km": round(d, 1)}
    return best


# GOES regional sector centers (approx lat/lon) for nearest-sector pick.
# Source: NESDIS STAR ABI sector imagery.
GOES_SECTORS = {
    "pnw": ("Pacific Northwest", 45.5, -120.0),
    "psw": ("Pacific Southwest", 36.0, -119.0),
    "nr":  ("Northern Rockies", 46.0, -108.0),
    "sr":  ("Southern Rockies", 35.0, -106.0),
    "umv": ("Upper Mississippi Valley", 43.0, -92.0),
    "smv": ("Southern Mississippi Valley", 33.0, -91.0),
    "cgl": ("Central Great Lakes", 43.0, -85.0),
    "ne":  ("Northeast", 42.5, -74.0),
    "se":  ("Southeast", 32.0, -82.0),
}

def nearest_goes_sector(lat, lon):
    best, best_d = "umv", 1e9
    for code, (_, slat, slon) in GOES_SECTORS.items():
        d = haversine_km(lat, lon, slat, slon)
        if d < best_d:
            best_d, best = d, code
    return best, GOES_SECTORS[best][0]


# ──────────────────────────────────────────────────────────────────────────
# Image suite manifest
# ──────────────────────────────────────────────────────────────────────────

def resolve_snow_url():
    """NOHRSC snow-depth filenames are dated; try the last few days at 05Z and
    return the first that exists. Returns a URL (caller skips gracefully on 404)."""
    base = "https://www.nohrsc.noaa.gov/snow_model/images/full/National/nsm_depth"
    today = dt.date.today()
    for back in range(0, 4):
        d = today - dt.timedelta(days=back)
        url = f"{base}/{d:%Y%m}/nsm_depth_{d:%Y%m%d}05_National.jpg"
        try:
            h = requests.head(url, headers=NWS_HEADERS, timeout=8)
            if h.status_code == 200:
                return url
        except Exception:
            pass
    return f"{base}/{today:%Y%m}/nsm_depth_{today:%Y%m%d}05_National.jpg"


def build_manifest(loc, station, sector_code, sector_name, point_meta=None):
    """Each entry: key, title, category, scope, url, prompt(loc)->str."""
    point_meta = point_meta or {"wfo": "", "zone": ""}
    place = loc["label"]
    region = sector_name
    sid = station["id"] if station else None

    def p_radar_local(_):
        return (
            f"You are describing a NWS NEXRAD base-reflectivity weather radar image "
            f"for a blind user near {place}. The map is centered on the radar station "
            f"and {place} is labeled on it.\n\n"
            "COLORS: solid blue/cyan/teal filled regions are BODIES OF WATER (lakes, "
            "coastlines), NOT precipitation. Scattered BLUE patches ARE light rain "
            "(5-35 dBZ) and are the most common precipitation color. green=light, "
            "yellow=moderate, orange/red=heavy, pink/purple=extreme or hail. Thin red "
            "or brown lines are county/state borders, not storms. The colored boxes "
            "along the very top are a warning legend key, not actual warnings.\n\n"
            f"In 3-4 sentences: Is precipitation visible? Where is it relative to "
            f"{place} (which direction, how far)? How intense? Is {place} itself under "
            "precipitation right now?")

    def p_radar_national(_):
        return (
            "You are describing the NATIONAL US radar mosaic for a blind user. The "
            f"home location is {place} ({region} region).\n\n"
            "Blue/green=light rain, yellow=moderate, orange/red=heavy, pink=extreme. "
            "In 3-4 sentences: Where are the major areas of precipitation across the "
            f"country? Is there an organized system near {place} or its region? Give a "
            "big-picture sense of where the active weather is.")

    def p_goes_geocolor(_):
        return (
            "You are describing a GOES GeoColor satellite image (true-color by day, "
            f"infrared clouds plus city lights by night) of the {region} region for a "
            f"blind user. The home location is {place}.\n\n"
            "In 3-4 sentences: How much cloud cover is there, and where? Are skies clear "
            f"or cloudy over {place}? Are there any organized storm systems, swirls, or "
            "lines of clouds, and where are they relative to the home location?")

    def p_goes_ir(_):
        return (
            "You are describing a GOES Band 13 'Clean Infrared' satellite image of the "
            f"{region} region for a blind user. In infrared, the COLDEST cloud tops are "
            "the brightest white (or colored by an enhancement) and correspond to the "
            f"TALLEST, strongest storm clouds. The home location is {place}.\n\n"
            "In 3-4 sentences: Where are the coldest/tallest cloud tops (strongest "
            f"storms)? Are any near {place}? Where is it clear (warm/dark)?")

    def p_goes_wv(_):
        return (
            "You are describing a GOES Band 9 mid-level Water Vapor satellite image of "
            f"the {region} region for a blind user. Brighter areas = more moisture in "
            "the mid atmosphere; darker areas = dry air. Swirls and sharp boundaries "
            f"reveal the jet stream and storm dynamics. Home location is {place}.\n\n"
            "In 3-4 sentences: Where is the atmosphere moist vs dry? Are there swirls or "
            f"sharp dry/moist boundaries (jet stream features) near {place}?")

    def p_qpf(_):
        return (
            "You are describing a NWS Weather Prediction Center 'QPF' map for a blind "
            "user. It shows forecast PRECIPITATION AMOUNTS over the next 24 hours as "
            "colored/contoured regions over the United States; greens/yellows = lighter "
            f"amounts, oranges/reds/purples = heavier. Home location is {place} "
            f"({region}).\n\n"
            "In 3-4 sentences: Where is the heaviest rain forecast? Is significant "
            f"precipitation expected near {place} or its region in the next day?")

    def p_fronts(_):
        return (
            "You are describing a NWS surface analysis weather map for a blind user. It "
            "shows fronts and pressure systems across North America: blue lines with "
            "triangles = cold fronts, red lines with half-circles = warm fronts, lines "
            "with both = stationary/occluded fronts, 'H' = high pressure, 'L' = low "
            f"pressure. Home location is {place} ({region}).\n\n"
            "In 3-4 sentences: Where are the main fronts and pressure centers? Is any "
            f"front or low approaching {place} or its region, and from which direction?")

    def p_airmass(_):
        return (
            "You are describing a GOES 'Air Mass RGB' satellite image of the "
            f"{region} region for a blind user. This false-color product reveals "
            "air masses and upper-level dynamics: GREEN = warm, moist tropical air; "
            "ORANGE/RED/TAN = warm, dry air; BLUE/PURPLE = cold, dry stratospheric air "
            "associated with the jet stream and dry intrusions behind storms; white = "
            f"thick cold cloud. Home location is {place}.\n\n"
            "In 3-4 sentences: What air masses are present and where? Is there a jet "
            f"stream or dry intrusion (purple/blue) near {place} that signals "
            "developing or strengthening weather?")

    def p_qpf2(_):
        return (
            "You are describing a NWS Weather Prediction Center 'Day 2' QPF map for a "
            "blind user — forecast PRECIPITATION AMOUNTS for the 24-hour period roughly "
            "one to two days out, as colored/contoured regions over the US; greens = "
            "lighter, oranges/reds/purples = heavier. Home location is "
            f"{place} ({region}).\n\n"
            "In 3-4 sentences: Where is the heaviest rain forecast on day 2? Is "
            f"significant precipitation expected near {place} or its region?")

    def p_drought(_):
        return (
            "You are describing the US Drought Monitor map for a blind user. It shades "
            "drought severity: white/none, then yellow (D0 abnormally dry), tan (D1 "
            "moderate), orange (D2 severe), red (D3 extreme), dark red (D4 "
            f"exceptional). Home location is {place} ({region}).\n\n"
            "In 2-3 sentences: Which parts of the country are in the worst drought? Is "
            f"{place} or its region in any drought category, and how severe?")

    def p_tropical(_):
        return (
            "You are describing the National Hurricane Center 7-day Tropical Weather "
            "Outlook for the Atlantic basin, for a blind user. Hatched/shaded areas mark "
            "where tropical systems may form over 7 days: yellow = low chance, orange = "
            "medium, red = high; named storms or current systems are also marked.\n\n"
            "In 2-3 sentences: Are there any active tropical systems or areas to watch, "
            "and where (e.g. Gulf, Caribbean, central Atlantic)? Is anything threatening "
            "the US coast?")

    def p_snow(_):
        return (
            "You are describing a NOHRSC national snow depth map for a blind user. It "
            "shades modeled snow on the ground: blues/purples for deeper snow, white/tan "
            f"for little or none. Home location is {place} ({region}).\n\n"
            "In 2-3 sentences: Where is the deepest snow cover? Is there any snow on the "
            f"ground near {place} or its region?")

    def p_meteogram(_):
        return (
            "You are describing a NWS hourly forecast meteogram (a multi-panel line "
            f"graph) for {place}, for a blind user. Panels typically show temperature, "
            "precipitation probability/amount, sky cover, and wind over the next 1-2 "
            "days, with time running left to right.\n\n"
            "In 4-5 sentences: What is the temperature trend (rising/falling, rough "
            "high and low)? When are precipitation chances highest? Any notable wind or "
            "sky-cover changes? Read it like a short forecast narrative.")

    items = []
    if sid:
        items.append(dict(
            key="radar_local", title=f"Local radar ({sid})",
            category="Now — Local", scope=f"~250 km around {place}",
            url=f"https://radar.weather.gov/ridge/standard/{sid}_0.gif",
            prompt=p_radar_local, sonify=True))
    items += [
        dict(key="radar_national", title="National radar mosaic",
             category="Now — National", scope="Continental US",
             url="https://radar.weather.gov/ridge/standard/CONUS_0.gif",
             prompt=p_radar_national),
        dict(key="goes_geocolor", title=f"Satellite — GeoColor ({region})",
             category="Now — Regional satellite", scope=region,
             url=f"https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/{sector_code}/GEOCOLOR/1200x1200.jpg",
             prompt=p_goes_geocolor),
        dict(key="goes_ir", title=f"Satellite — Clean Infrared ({region})",
             category="Now — Regional satellite", scope=region,
             url=f"https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/{sector_code}/13/1200x1200.jpg",
             prompt=p_goes_ir),
        dict(key="goes_wv", title=f"Satellite — Water Vapor ({region})",
             category="Now — Regional satellite", scope=region,
             url=f"https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/{sector_code}/09/1200x1200.jpg",
             prompt=p_goes_wv),
        dict(key="goes_airmass", title=f"Satellite — Air Mass RGB ({region})",
             category="Now — Regional satellite", scope=region,
             url=f"https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/{sector_code}/AirMass/1200x1200.jpg",
             prompt=p_airmass),
        dict(key="forecast_qpf", title="Rain forecast — day 1 (WPC QPF)",
             category="Forecast", scope="Continental US",
             url="https://www.wpc.ncep.noaa.gov/qpf/94qwbg.gif",
             prompt=p_qpf),
        dict(key="forecast_qpf_day2", title="Rain forecast — day 2 (WPC QPF)",
             category="Forecast", scope="Continental US",
             url="https://www.wpc.ncep.noaa.gov/qpf/98qwbg.gif",
             prompt=p_qpf2),
        dict(key="surface_fronts", title="Fronts & pressure (surface analysis)",
             category="Forecast", scope="North America",
             url="https://www.wpc.ncep.noaa.gov/noaa/noaad1.gif",
             prompt=p_fronts),
        dict(key="tropical_atlantic", title="Tropical outlook — Atlantic (NHC 7-day)",
             category="Hazard outlooks", scope="Atlantic basin",
             url="https://www.nhc.noaa.gov/xgtwo/two_atl_7d0.png",
             prompt=p_tropical),
        dict(key="drought", title="US Drought Monitor",
             category="Hazard outlooks", scope="United States",
             url="https://droughtmonitor.unl.edu/data/png/current/current_usdm.png",
             prompt=p_drought),
        dict(key="snow_depth", title="Snow depth (NOHRSC, best-effort)",
             category="Hazard outlooks", scope="United States",
             url=resolve_snow_url(),
             prompt=p_snow),
    ]
    # Local meteogram needs the correct forecast office (wfo) + zone for this point,
    # otherwise the Plotter returns a blank strip. Skip if we couldn't resolve them.
    if point_meta.get("wfo") and point_meta.get("zone"):
        items.append(dict(
            key="meteogram", title=f"Hourly forecast graph — {place}",
            category="Local graph", scope=place,
            url=("https://forecast.weather.gov/meteograms/Plotter.php?"
                 f"lat={loc['lat']:.4f}&lon={loc['lon']:.4f}"
                 f"&wfo={point_meta['wfo']}&zcode={point_meta['zone']}&gset=18"
                 "&gdiff=3&unit=0&tinfo=EY5&ahour=0&pcmd=11011111111100000000000000000"
                 "000000000000000000000000000000000&lg=en&indu=1!1!1!&dd=&bw=&hrspan=24"
                 "&pqpfhr=6&psnwhr=6"),
            prompt=p_meteogram))
    return items


# ──────────────────────────────────────────────────────────────────────────
# Fetch + AI describe
# ──────────────────────────────────────────────────────────────────────────

def download(url):
    r = requests.get(url, headers=NWS_HEADERS, timeout=TIMEOUT)
    r.raise_for_status()
    ct = r.headers.get("content-type", "")
    if "image" not in ct:
        raise ValueError(f"not an image ({ct})")
    return r.content, ct


def to_png_bytes(image_bytes):
    """Normalize any image (gif/jpg) to PNG bytes for Ollama."""
    if not HAVE_PIL:
        return image_bytes
    im = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    out = io.BytesIO()
    im.save(out, format="PNG")
    return out.getvalue()


def _clean_fm_error(raw):
    """Map FM's giant nested error blobs to a short, screen-reader-friendly note.
    Returns (message, transient?)."""
    if "SensitiveContentAnalysis" in raw:
        return "[FM declined this image — on-device sensitive-content filter]", False
    if "error 1001" in raw or "Code=1001" in raw:
        return "[FM model busy (1001)]", True
    if "error 1046" in raw or "Code=1046" in raw:
        return "[FM model warming up (1046)]", True
    if "unavailable" in raw.lower():
        return "[FM unavailable]", False
    return f"[FM error] {raw.strip()[:160]}", True


def describe_fm(image_path, prompt, retries=2):
    """Apple Foundation Models via the Swift runner. Each call spins up the model
    in a fresh process; rapid back-to-back calls can hit transient 1001/1046
    errors, so retry those with a short backoff."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
        f.write(prompt)
        pf = f.name
    try:
        last = "[FM returned nothing]"
        for attempt in range(retries + 1):
            try:
                out = subprocess.run(
                    [str(HERE / "run_fm_image.sh"), pf, str(image_path)],
                    capture_output=True, text=True, timeout=180)
                txt = (out.stdout or "").strip()
                if txt and not txt.startswith("ERROR:"):
                    return txt
                raw = txt[6:] if txt.startswith("ERROR:") else (out.stderr or txt)
                msg, transient = _clean_fm_error(raw)
                last = msg
                if not transient:
                    return msg
            except subprocess.TimeoutExpired:
                last = "[FM timed out]"
            if attempt < retries:
                time.sleep(3 + attempt * 3)  # 3s, then 6s
        return last
    finally:
        os.unlink(pf)


def describe_ollama(image_bytes, prompt, model="minicpm-v4.6:latest"):
    png = to_png_bytes(image_bytes)
    b64 = base64.b64encode(png).decode()
    payload = {"model": model, "stream": False,
               "messages": [{"role": "user", "content": prompt, "images": [b64]}]}
    try:
        r = requests.post("http://localhost:11434/api/chat", json=payload, timeout=240)
        r.raise_for_status()
        return r.json()["message"]["content"].strip()
    except Exception as e:
        return f"[Ollama error] {e}"


# ──────────────────────────────────────────────────────────────────────────
# NWS ground truth
# ──────────────────────────────────────────────────────────────────────────

def nws_point_meta(lat, lon):
    """Return {wfo, zone} for the meteogram Plotter (needs the correct forecast
    office, not a hardcoded one). Empty strings if unavailable."""
    out = {"wfo": "", "zone": ""}
    try:
        r = requests.get(f"https://api.weather.gov/points/{lat:.4f},{lon:.4f}",
                         headers=NWS_HEADERS, timeout=TIMEOUT)
        props = r.json()["properties"]
        out["wfo"] = props.get("cwa", "") or props.get("gridId", "")
        fz = props.get("forecastZone", "")
        if fz:
            out["zone"] = fz.rstrip("/").split("/")[-1]
    except Exception:
        pass
    return out


def nws_ground_truth(lat, lon):
    out = {"conditions": "", "temp_f": None, "alerts": [], "error": None}
    try:
        pr = requests.get(f"https://api.weather.gov/points/{lat:.4f},{lon:.4f}",
                          headers=NWS_HEADERS, timeout=TIMEOUT)
        pr.raise_for_status()
        props = pr.json()["properties"]
        su = props.get("observationStations", "")
        if su:
            sr = requests.get(su, headers=NWS_HEADERS, timeout=TIMEOUT)
            feats = sr.json().get("features", [])
            if feats:
                sid = feats[0]["properties"]["stationIdentifier"]
                obs = requests.get(
                    f"https://api.weather.gov/stations/{sid}/observations/latest",
                    headers=NWS_HEADERS, timeout=TIMEOUT).json()["properties"]
                out["conditions"] = obs.get("textDescription", "")
                t = obs.get("temperature", {}).get("value")
                if t is not None:
                    out["temp_f"] = round(t * 9 / 5 + 32)
        ar = requests.get(
            f"https://api.weather.gov/alerts/active?point={lat:.4f},{lon:.4f}",
            headers=NWS_HEADERS, timeout=TIMEOUT).json()
        out["alerts"] = [a["properties"]["event"] for a in ar.get("features", [])]
    except Exception as e:
        out["error"] = str(e)
    return out


# ──────────────────────────────────────────────────────────────────────────
# Audio: radar sonification (non-speech; VoiceOver handles reading text)
# ──────────────────────────────────────────────────────────────────────────

# NWS RIDGE reflectivity color → intensity 0..1 (approx; reused from archive tool)
def _intensity_at(rgb):
    r, g, b = rgb[:3]
    # water / background / borders → 0
    if abs(r - g) < 18 and abs(g - b) < 18:      # gray/white/black neutral
        return 0.0
    if b > 150 and b > r + 30 and g < 160 and r < 140:
        # could be light blue rain OR water; water tends very saturated cyan.
        if g > 180 and b > 200:                  # cyan-ish water
            return 0.0
        return 0.25                              # light blue rain
    if g > 150 and r < 150 and b < 150:
        return 0.4                               # green
    if r > 180 and g > 180 and b < 120:
        return 0.6                               # yellow
    if r > 180 and 80 < g < 180 and b < 100:
        return 0.75                              # orange
    if r > 150 and g < 100 and b < 100:
        return 0.9                               # red
    if r > 150 and b > 150 and g < 130:
        return 1.0                               # magenta/extreme
    return 0.0


def sonify_radar(image_bytes, out_path, duration=4.0, rate=22050):
    """
    Creative audio experiment: a clockwise 'audio radar sweep' of precipitation
    around the location (image center ≈ radar station). Eight compass sectors are
    sampled N→NE→E…→NW. Each plays a short tone: PITCH rises with precipitation
    intensity, VOLUME with how much of that sector is covered, and STEREO PAN
    follows the east/west direction (west=left ear, east=right ear). Silence in a
    sector means clear sky that direction. Returns (filename, summary list).
    """
    if not HAVE_PIL:
        return None, []
    im = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    W, H = im.size
    px = im.load()
    cx, cy = W / 2, H / 2
    maxr = min(W, H) / 2 * 0.95
    # 8 sectors, clockwise from North. screen y grows downward.
    names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    sums = [0.0] * 8
    counts = [0] * 8
    step = max(1, int(min(W, H) / 220))  # sample grid
    for y in range(0, H, step):
        for x in range(0, W, step):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r < maxr * 0.04 or r > maxr:
                continue
            inten = _intensity_at(px[x, y])
            ang = (math.degrees(math.atan2(dx, -dy))) % 360  # 0=N, clockwise
            s = int((ang + 22.5) // 45) % 8
            counts[s] += 1
            sums[s] += inten
    # per-sector mean intensity and coverage
    sectors = []
    for i in range(8):
        if counts[i] == 0:
            sectors.append((names[i], 0.0, 0.0)); continue
        mean = sums[i] / counts[i]
        cover = sum(1 for _ in range(0))  # placeholder
        sectors.append((names[i], mean, sums[i] / max(counts[i], 1)))
    # build audio
    seg = duration / 8
    nseg = int(rate * seg)
    samples = []  # (L, R)
    pan_for = {"N": 0.0, "NE": 0.6, "E": 1.0, "SE": 0.6,
               "S": 0.0, "SW": -0.6, "W": -1.0, "NW": -0.6}
    summary = []
    for name, mean, _cover in sectors:
        f = 220 + mean * 700           # 220 Hz (light) → ~920 Hz (extreme)
        amp = 0.0 if mean <= 0.02 else min(0.9, 0.25 + mean)
        pan = pan_for[name]
        lg = math.sqrt((1 - pan) / 2) if amp else 0
        rg = math.sqrt((1 + pan) / 2) if amp else 0
        for n in range(nseg):
            env = math.sin(math.pi * n / nseg)  # fade in/out
            s = amp * env * math.sin(2 * math.pi * f * n / rate)
            samples.append((s * lg, s * rg))
        if amp:
            summary.append(f"{name}: {'light' if mean<0.35 else 'moderate' if mean<0.6 else 'heavy'}")
    with wave.open(str(out_path), "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
        frames = bytearray()
        for l, r in samples:
            frames += struct.pack("<hh", int(max(-1, min(1, l)) * 32767),
                                  int(max(-1, min(1, r)) * 32767))
        w.writeframes(bytes(frames))
    return out_path.name, summary


# ──────────────────────────────────────────────────────────────────────────
# HTML report
# ──────────────────────────────────────────────────────────────────────────

def build_html(run_dir, loc, station, sector_name, gt, items, ai_modes, gen_time):
    rows = []
    cats = []
    for it in items:
        if it["category"] not in cats:
            cats.append(it["category"])

    def section(it):
        h = [f'<section aria-labelledby="h-{it["key"]}">',
             f'<h3 id="h-{it["key"]}">{escape(it["title"])}</h3>',
             f'<p class="scope">Coverage: {escape(it["scope"])}</p>']
        if it.get("error"):
            h.append(f'<p class="err">Could not fetch: {escape(it["error"])}</p>')
            h.append("</section>")
            return "\n".join(h)
        # AI description(s) first — that's what a screen-reader user reads.
        for mode in ai_modes:
            desc = it.get(f"desc_{mode}")
            if desc:
                label = {"fm": "Apple Foundation Models",
                         "ollama": "Ollama (minicpm-v)"}.get(mode, mode)
                h.append(f'<div class="desc"><p class="who">{label} says:</p>'
                         f'<p>{escape(desc)}</p></div>')
        if it.get("sonify_file"):
            ss = it.get("sonify_summary") or []
            cap = ("Precipitation by direction: " + "; ".join(ss)) if ss \
                  else "No precipitation detected around the location."
            h.append(f'<div class="desc"><p class="who">Audio radar sweep '
                     f'(clockwise from north, west=left ear, east=right ear; '
                     f'pitch rises with intensity):</p><p>{escape(cap)}</p>'
                     f'<audio controls preload="none" src="audio/{it["sonify_file"]}" '
                     f'aria-label="Sonified radar sweep around {escape(loc["label"])}">'
                     f'</audio></div>')
        # image last, with AI text as alt so VoiceOver on the image is useful too.
        alt = it.get("desc_fm") or it.get("desc_ollama") or it["title"]
        h.append(f'<img src="images/{it["file"]}" alt="{escape(alt)}" />')
        h.append("</section>")
        return "\n".join(h)

    body = []
    for cat in cats:
        body.append(f'<h2>{escape(cat)}</h2>')
        for it in items:
            if it["category"] == cat:
                body.append(section(it))

    alerts = (", ".join(gt["alerts"]) if gt.get("alerts") else "None")
    cond = gt.get("conditions") or "unavailable"
    temp = f'{gt["temp_f"]}°F' if gt.get("temp_f") is not None else "n/a"
    st = (f'{station["name"]} ({station["id"]}), {station["dist_km"]} km away'
          if station else "none found")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Weather Images — {escape(loc["label"])}</title>
<style>
 body {{ font: 17px/1.6 -apple-system, system-ui, sans-serif; max-width: 820px;
        margin: 0 auto; padding: 1rem; color: #111; background: #fff; }}
 h1 {{ font-size: 1.6rem; }}
 h2 {{ margin-top: 2.2rem; border-bottom: 2px solid #0a5; padding-bottom: .2rem; }}
 h3 {{ margin-bottom: .1rem; }}
 .scope {{ color: #555; font-size: .9rem; margin: 0 0 .6rem; }}
 .desc {{ background: #f3f7f4; border-left: 4px solid #0a5; padding: .6rem .9rem;
          margin: .6rem 0; border-radius: 4px; }}
 .who {{ font-weight: 600; margin: 0 0 .3rem; color: #064; }}
 .err {{ color: #a00; }}
 img {{ max-width: 100%; height: auto; border: 1px solid #ccc; border-radius: 6px;
        margin: .6rem 0 1.4rem; }}
 audio {{ width: 100%; margin-top: .4rem; }}
 .meta {{ background: #fafafa; border: 1px solid #ddd; border-radius: 6px;
          padding: .8rem 1rem; }}
 a.skip {{ position: absolute; left: -999px; }}
 a.skip:focus {{ position: static; }}
</style>
</head>
<body>
<a class="skip" href="#suite">Skip to weather images</a>
<h1>Weather Images — {escape(loc["label"])}</h1>
<p>Experimental suite of free NOAA/NWS weather imagery, each described by AI for
non-visual reading. Generated {escape(gen_time)}.</p>
<section class="meta" aria-labelledby="ground-truth">
<h2 id="ground-truth" style="margin-top:0;border:none">Ground truth right now</h2>
<ul>
<li>Location: {escape(loc["label"])} ({loc["lat"]:.3f}, {loc["lon"]:.3f})</li>
<li>Nearest radar station: {escape(st)}</li>
<li>Satellite sector: {escape(sector_name)}</li>
<li>Observed conditions: {escape(cond)}, {escape(temp)}</li>
<li>Active NWS alerts: {escape(alerts)}</li>
</ul>
<p style="color:#555;font-size:.9rem">Use this to judge how accurate each AI
description is. Descriptions are AI-generated and may be wrong.</p>
</section>
<h2 id="suite" style="border:none">Image suite</h2>
{''.join(body)}
<footer style="margin-top:3rem;color:#666;font-size:.85rem">
<p>All imagery © NOAA/NWS, public domain. AI descriptions: {escape(", ".join(ai_modes) or "none")}.
This is an accessibility research bench, not a weather service.</p>
</footer>
</body>
</html>"""
    (run_dir / "report.html").write_text(html, encoding="utf-8")


# ──────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────

def build_master_index(runs_root):
    """Scan every run's data.json and write runs/index.html — a VoiceOver-scannable
    list of all reports (newest first) with location, time, conditions, and alerts."""
    runs_root = Path(runs_root)
    entries = []
    for dj in runs_root.glob("*/data.json"):
        try:
            d = json.loads(dj.read_text())
        except Exception:
            continue
        gt = d.get("ground_truth", {})
        entries.append({
            "dir": dj.parent.name,
            "label": d.get("location", {}).get("label", dj.parent.name),
            "generated": d.get("generated", ""),
            "cond": gt.get("conditions", ""),
            "temp": gt.get("temp_f"),
            "alerts": gt.get("alerts", []),
            "n": sum(1 for it in d.get("items", []) if it.get("file")),
        })
    entries.sort(key=lambda e: e["generated"], reverse=True)
    rows = []
    for e in entries:
        temp = f', {e["temp"]}°F' if e["temp"] is not None else ""
        alerts = (" — ⚠ " + ", ".join(e["alerts"])) if e["alerts"] else ""
        rows.append(
            f'<li><a href="{escape(e["dir"])}/report.html"><strong>'
            f'{escape(e["label"])}</strong></a> — {escape(e["generated"])}, '
            f'{e["n"]} images. {escape(e["cond"] or "")}{escape(temp)}'
            f'{escape(alerts)}</li>')
    html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Weather Images Lab — all runs</title>
<style>
 body {{ font: 17px/1.6 -apple-system, system-ui, sans-serif; max-width: 820px;
        margin: 0 auto; padding: 1rem; }}
 li {{ margin: .5rem 0; }} a {{ color: #064; }}
</style></head><body>
<h1>Weather Images Lab — all runs</h1>
<p>{len(entries)} report(s), newest first. Each links to a full image suite.</p>
<ul>
{chr(10).join(rows) or "<li>No runs yet.</li>"}
</ul>
</body></html>"""
    (runs_root / "index.html").write_text(html, encoding="utf-8")
    return runs_root / "index.html"


def process_location(loc_arg, args, ai_modes):
    print(f"\nResolving '{loc_arg}'…")
    loc = resolve_location(loc_arg)
    print(f"  {loc['label']}  ({loc['lat']:.3f}, {loc['lon']:.3f})")

    station = nearest_nexrad(loc["lat"], loc["lon"])
    print(f"  radar station: {station['id'] if station else 'none'}")
    sector_code, sector_name = nearest_goes_sector(loc["lat"], loc["lon"])
    print(f"  satellite sector: {sector_code} ({sector_name})")
    point_meta = nws_point_meta(loc["lat"], loc["lon"])

    items = build_manifest(loc, station, sector_code, sector_name, point_meta)
    if args.only:
        keep = set(args.only.split(","))
        items = [it for it in items if it["key"] in keep]

    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    safe = "".join(c if c.isalnum() else "_" for c in loc["label"])[:30]
    run_dir = Path(args.out) / f"{stamp}_{safe}"
    (run_dir / "images").mkdir(parents=True, exist_ok=True)
    if not args.no_audio:
        (run_dir / "audio").mkdir(exist_ok=True)

    print("Fetching NWS ground truth…")
    gt = nws_ground_truth(loc["lat"], loc["lon"])

    for it in items:
        print(f"\n[{it['key']}] {it['title']}")
        try:
            img_bytes, ct = download(it["url"])
        except Exception as e:
            print(f"  fetch failed: {e}")
            it["error"] = str(e)
            continue
        ext = ".gif" if "gif" in ct else ".png" if "png" in ct else ".jpg"
        fname = it["key"] + ext
        (run_dir / "images" / fname).write_bytes(img_bytes)
        it["file"] = fname
        print(f"  saved {fname} ({len(img_bytes)//1024} KB)")

        prompt = it["prompt"](loc)
        for mode in ai_modes:
            print(f"  describing with {mode}…", end="", flush=True)
            if mode == "fm":
                desc = describe_fm(run_dir / "images" / fname, prompt)
                time.sleep(1.0)  # let the on-device model settle between calls
            else:
                desc = describe_ollama(img_bytes, prompt, args.ollama_model)
            it[f"desc_{mode}"] = desc
            print(" done")
            (run_dir / f"{it['key']}.{mode}.txt").write_text(desc, encoding="utf-8")

        if it.get("sonify") and not args.no_audio:
            print("  sonifying radar…", end="", flush=True)
            sf, summ = sonify_radar(img_bytes, run_dir / "audio" / f"{it['key']}_sweep.wav")
            it["sonify_file"] = sf
            it["sonify_summary"] = summ
            print(" done")

    gen_time = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    build_html(run_dir, loc, station, sector_name, gt, items, ai_modes, gen_time)

    rec = {"location": loc, "station": station, "sector": sector_name,
           "ground_truth": gt, "ai_modes": ai_modes, "generated": gen_time,
           "items": [{k: v for k, v in it.items() if k != "prompt"} for it in items]}
    (run_dir / "data.json").write_text(json.dumps(rec, indent=2), encoding="utf-8")
    print(f"  ✅ {run_dir / 'report.html'}")
    return run_dir


def main():
    ap = argparse.ArgumentParser(description="Weather Images experimentation lab")
    ap.add_argument("location", nargs="+",
                    help="one or more US zip codes or place names")
    ap.add_argument("--ai", choices=["fm", "ollama", "both", "none"], default="fm")
    ap.add_argument("--only", help="comma-separated keys to include")
    ap.add_argument("--no-audio", action="store_true",
                    help="skip radar sonification (the only audio; descriptions are text)")
    ap.add_argument("--ollama-model", default="minicpm-v4.6:latest")
    ap.add_argument("--out", default=str(HERE / "runs"))
    args = ap.parse_args()

    ai_modes = {"fm": ["fm"], "ollama": ["ollama"],
                "both": ["fm", "ollama"], "none": []}[args.ai]

    last = None
    for loc_arg in args.location:
        try:
            last = process_location(loc_arg, args, ai_modes)
        except Exception as e:
            print(f"  ✗ {loc_arg} failed: {e}")

    idx = build_master_index(args.out)
    print(f"\n✅ {len(args.location)} location(s) done.")
    print(f"   All runs index: open '{idx}'")
    if last:
        print(f"   Latest report:  open '{last / 'report.html'}'")


if __name__ == "__main__":
    main()
