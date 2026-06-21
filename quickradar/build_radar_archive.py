#!/usr/bin/env python3
"""
build_radar_archive.py
======================

Manually-run image archive builder for the radar test bed.

When you run this, it:
  1. Checks NWS active alerts across the US and finds the radar stations
     closest to currently-alerting areas.
  2. Downloads radar images for those alert areas PLUS a fixed geographic
     diversity sweep.
  3. Pixel-analyses each image to determine whether colored echoes are
     present (not just looking at NWS text conditions).
  4. Saves "interesting" images (has echoes OR has active alerts) to a
     permanent archive at archive/ with full NWS metadata JSON.
  5. Runs a cloud vision model against each saved image and stores the
     description in the JSON metadata (so each entry has a high-quality
     baseline description alongside the ground truth).
  6. Prints a capture summary showing what was saved and why.

After running, you have a growing archive of radar images spanning the
full range of conditions (clear, light, moderate, heavy, warnings) that
you can use as a fixed test bed for model comparison.

Usage:
    python build_radar_archive.py               # full run, all locations, local models
    python build_radar_archive.py --no-alerts   # skip NWS alert hunting, just geo sweep
    python build_radar_archive.py --no-local    # skip local model descriptions (faster)
    python build_radar_archive.py --local-models minicpm-v4.6,qwen3-vl:2b  # custom model list
    python build_radar_archive.py --cloud-model gemini-3-flash-preview:cloud  # add cloud too
    python build_radar_archive.py --label       # show images needing VoiceOver labels

All locations are always saved — every run produces a complete, equal-sized dataset.

The archive layout:
    archive/
        YYYYMMDD_HHMMSS_ZIPCODE_STATION_CITY.png      ← radar image (PNG)
        YYYYMMDD_HHMMSS_ZIPCODE_STATION_CITY.json     ← NWS metadata + pixel analysis
        voiceover/
            YYYYMMDD_HHMMSS_ZIPCODE_STATION_CITY.txt  ← VoiceOver description (paste here)
        index.jsonl                                    ← one line per archived entry
"""

import argparse
import base64
import io
import json
import math
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

NWS_HEADERS = {
    "Accept": "application/geo+json",
    "User-Agent": "QuickRadarArchive/1.0 (weather-app research; contact: local)",
}

ARCHIVE_DIR = Path("archive")  # overridden by --output-dir at runtime

DEFAULT_LOCAL_MODELS = "minicpm-v4.6"
DEFAULT_CLOUD_MODEL = "gemini-3-flash-preview:cloud"

CLOUD_PROMPT = """You are describing a NWS NEXRAD base-reflectivity radar image for a blind user. Be accurate and specific.

COLORS — learn these before describing anything:
  SOLID BLUE, CYAN, or TEAL filled areas = BODIES OF WATER (Great Lakes, rivers, coastlines). These are NOT precipitation. They are permanent map features.
  WHITE or LIGHT GRAY areas = NO precipitation detected.
  LIGHT GREEN = very light rain/drizzle.
  GREEN = light rain.
  YELLOW = moderate rain.
  ORANGE = heavy rain.
  RED or DARK RED = very heavy rain or large hail.
  PINK or MAGENTA = ice or extreme precipitation.

LINES — do not confuse these with weather:
  THIN RED or BROWN LINES = county and state borders. NOT storm outlines.

TOP OF IMAGE — warning legend strip:
  The very top of the image has a row of colored boxes (Tornado Warning, Severe Thunderstorm Warning, Flash Flood Warning, etc.). These are a LEGEND KEY — they show what color would be used IF a warning existed. Do not report a warning just because you see these colored boxes. Only report a warning if you see a colored polygon or outlined shape drawn ON the MAP itself, below the legend strip.

WHAT TO DESCRIBE:
1. Is there any precipitation visible on the map (green/yellow/orange/red/pink areas)? If yes: where is it, what intensity, roughly how large an area?
2. Are any colored polygons or warning outlines drawn ON the map area (not the top legend strip)?
3. Is the map mostly clear or active?
Answer each of these three questions. Be specific and factual."""

# ── Geographic diversity sweep (same 20 as the main experiment) ─────────────
GEO_SWEEP = [
    ("53703", "Madison WI"),
    ("60601", "Chicago IL"),
    ("44101", "Cleveland OH"),
    ("30301", "Atlanta GA"),
    ("33101", "Miami FL"),
    ("28201", "Charlotte NC"),
    ("39401", "Hattiesburg MS"),
    ("70112", "New Orleans LA"),
    ("32201", "Jacksonville FL"),
    ("73072", "Norman OK"),
    ("67202", "Wichita KS"),
    ("79401", "Lubbock TX"),
    ("77002", "Houston TX"),
    ("10001", "New York NY"),
    ("02101", "Boston MA"),
    ("80202", "Denver CO"),
    ("98101", "Seattle WA"),
    ("94102", "San Francisco CA"),
    ("85001", "Phoenix AZ"),
    ("89101", "Las Vegas NV"),
]

# Echo categories (used in metadata)
ECHO_CATEGORIES = {
    "none":     "No echoes visible",
    "light":    "Light echoes (green only)",
    "moderate": "Moderate echoes (yellow/orange present)",
    "heavy":    "Heavy echoes (red/dark red present)",
    "extreme":  "Extreme echoes (pink/magenta present)",
}


# ── Haversine ───────────────────────────────────────────────────────────────
def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    dp = math.radians(lat2 - lat1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*R*math.asin(math.sqrt(a))


# ── Geocode a US zipcode ─────────────────────────────────────────────────────
def geocode(zipcode):
    r = requests.get(f"https://api.zippopotam.us/us/{zipcode}", timeout=15)
    r.raise_for_status()
    d = r.json()
    p = d["places"][0]
    return float(p["latitude"]), float(p["longitude"]), p["place name"]


# ── NWS radar station lookup ─────────────────────────────────────────────────
_radar_stations_cache = None

def radar_stations():
    global _radar_stations_cache
    if _radar_stations_cache is None:
        r = requests.get("https://api.weather.gov/radar/stations",
                         headers=NWS_HEADERS, timeout=30)
        r.raise_for_status()
        _radar_stations_cache = r.json().get("features", [])
    return _radar_stations_cache


def nearest_nexrad(lat, lon):
    best, best_d = None, None
    for st in radar_stations():
        coords = st.get("geometry", {}).get("coordinates")
        if not coords:
            continue
        props = st.get("properties", {})
        sid = props.get("id", "").upper()
        if not sid.startswith("K"):
            continue
        d = haversine_km(lat, lon, coords[1], coords[0])
        if best_d is None or d < best_d:
            best_d = d
            best = {"id": sid, "name": props.get("name", ""), "lat": coords[1], "lon": coords[0], "dist_km": d}
    return best


# ── Download radar image ─────────────────────────────────────────────────────
def download_radar(station_id):
    sid = station_id.upper()
    for url in [f"https://radar.weather.gov/ridge/standard/{sid}_0.gif",
                f"https://radar.weather.gov/ridge/standard/{sid}_0.png"]:
        try:
            r = requests.get(url, headers={"User-Agent": NWS_HEADERS["User-Agent"]}, timeout=20)
            if r.status_code == 200 and len(r.content) > 1000:
                return r.content, url
        except Exception:
            continue
    return None, None


# ── Pixel analysis: classify echo level ─────────────────────────────────────
def classify_echoes(image_bytes):
    """
    Quick pixel-level analysis to classify what's in the radar image.
    Returns (category, echo_fraction, details).
    NWS RIDGE color scale (approximate sRGB):
      No echo: gray/white
      Light (5-20 dBZ):  pale green/light green
      Moderate (20-40): green → yellow → orange
      Heavy (40-50):    orange → red
      Extreme (50+):    dark red → magenta/pink
    Bodies of water appear as solid teal/cyan (not precipitation).
    """
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        pixels = list(img.getdata())

        # Strip top 10% (legend) and bottom 8% (scale bar) from analysis
        w, h = img.size
        top_skip = int(h * 0.10)
        bot_skip = int(h * 0.08)
        row_start = top_skip * w
        row_end = (h - bot_skip) * w
        map_pixels = pixels[row_start:row_end]

        total = len(map_pixels)
        if total == 0:
            return "none", 0.0, {}

        counts = {"water": 0, "light": 0, "moderate": 0, "heavy": 0, "extreme": 0}
        for r, g, b in map_pixels:
            # Water bodies: teal/cyan (high G+B, low R)
            if b > 120 and g > 100 and r < 100 and (g + b) > (r * 2.5):
                counts["water"] += 1
            # Extreme: pink/magenta (high R+B, low G)
            elif r > 160 and b > 100 and g < 80:
                counts["extreme"] += 1
            # Heavy: orange to dark red (high R, moderate-low G, low B)
            elif r > 160 and g < 120 and b < 60:
                counts["heavy"] += 1
            # Moderate: yellow (high R+G, low B)
            elif r > 150 and g > 120 and b < 80:
                counts["moderate"] += 1
            # Light: green (high G, lower R, low B)
            elif g > 120 and r < 150 and b < 80:
                counts["light"] += 1

        echo_pixels = counts["light"] + counts["moderate"] + counts["heavy"] + counts["extreme"]
        echo_frac = echo_pixels / total

        if counts["extreme"] > total * 0.002:
            category = "extreme"
        elif counts["heavy"] > total * 0.005:
            category = "heavy"
        elif counts["moderate"] > total * 0.01:
            category = "moderate"
        elif counts["light"] > total * 0.02:
            category = "light"
        else:
            category = "none"

        return category, round(echo_frac, 4), {k: round(v/total, 4) for k, v in counts.items()}

    except ImportError:
        return "unknown", 0.0, {"error": "Pillow not installed"}
    except Exception as e:
        return "unknown", 0.0, {"error": str(e)}


# ── NWS ground truth for a point ────────────────────────────────────────────
def nws_ground_truth(lat, lon):
    result = {"conditions": "", "has_precip": False, "precip_description": "",
              "alerts": [], "station_id": "", "obs_time": "", "error": None}
    try:
        pr = requests.get(f"https://api.weather.gov/points/{lat:.4f},{lon:.4f}",
                          headers=NWS_HEADERS, timeout=20)
        pr.raise_for_status()
        props = pr.json().get("properties", {})
        stations_url = props.get("observationStations", "")
        if stations_url:
            sr = requests.get(stations_url, headers=NWS_HEADERS, timeout=20)
            sr.raise_for_status()
            feats = sr.json().get("features", [])
            if feats:
                sid = feats[0]["properties"].get("stationIdentifier", "")
                result["station_id"] = sid
                obs_r = requests.get(
                    f"https://api.weather.gov/stations/{sid}/observations/latest",
                    headers=NWS_HEADERS, timeout=20)
                obs_r.raise_for_status()
                obs = obs_r.json().get("properties", {})
                result["obs_time"] = obs.get("timestamp", "")
                result["conditions"] = obs.get("textDescription", "")
                def _val(f):
                    v = obs.get(f)
                    return v.get("value") if isinstance(v, dict) else v
                p1h = _val("precipitationLastHour")
                p3h = _val("precipitationLast3Hours")
                if p1h and p1h > 0:
                    result["has_precip"] = True
                    result["precip_description"] = f"{p1h:.1f} mm last hour"
                elif p3h and p3h > 0:
                    result["has_precip"] = True
                    result["precip_description"] = f"{p3h:.1f} mm last 3hr"
                for w in (obs.get("presentWeather") or []):
                    wt = w.get("weather", "")
                    if wt and wt.lower() not in ("", "none"):
                        result["has_precip"] = True
                        if not result["precip_description"]:
                            result["precip_description"] = wt
        ar = requests.get(f"https://api.weather.gov/alerts/active?point={lat:.4f},{lon:.4f}",
                          headers=NWS_HEADERS, timeout=20)
        ar.raise_for_status()
        for feat in ar.json().get("features", []):
            ap = feat.get("properties", {})
            result["alerts"].append({"event": ap.get("event",""), "headline": ap.get("headline","")})
    except Exception as e:
        result["error"] = str(e)
    return result


# ── Find locations near active alerts ────────────────────────────────────────
def alert_zipcodes(max_alerts=15):
    """
    Pull active NWS alerts, find coordinates, look up nearest zipcodes.
    Returns list of (zipcode, city, reason) tuples.
    Weather alert types we care about (radar-visible):
      Tornado Warning, Tornado Watch, Severe Thunderstorm Warning,
      Severe Thunderstorm Watch, Flash Flood Warning, Flash Flood Watch,
      Winter Storm Warning, Blizzard Warning, Snow Squall Warning
    """
    WEATHER_ALERT_TYPES = {
        "Tornado Warning", "Tornado Watch",
        "Severe Thunderstorm Warning", "Severe Thunderstorm Watch",
        "Flash Flood Warning", "Flash Flood Watch",
        "Winter Storm Warning", "Blizzard Warning",
        "Snow Squall Warning", "Flood Warning",
        "Special Marine Warning",
    }
    try:
        r = requests.get(
            "https://api.weather.gov/alerts/active?status=actual&message_type=alert",
            headers=NWS_HEADERS, timeout=30)
        r.raise_for_status()
        features = r.json().get("features", [])
    except Exception as e:
        print(f"  could not fetch active alerts: {e}")
        return []

    seen_coords = []
    alert_locs = []

    for feat in features:
        props = feat.get("properties", {})
        event = props.get("event", "")
        if event not in WEATHER_ALERT_TYPES:
            continue
        # Try to get a point coordinate
        geom = feat.get("geometry") or {}
        coords = None
        if geom.get("type") == "Point":
            coords = geom["coordinates"]
        elif geom.get("type") in ("Polygon", "MultiPolygon"):
            # Use centroid of first polygon ring
            rings = geom.get("coordinates", [])
            if rings:
                ring = rings[0] if geom["type"] == "Polygon" else rings[0][0]
                if ring:
                    avg_lon = sum(c[0] for c in ring) / len(ring)
                    avg_lat = sum(c[1] for c in ring) / len(ring)
                    coords = [avg_lon, avg_lat]

        if not coords:
            continue
        lon, lat = coords[0], coords[1]

        # Deduplicate: skip if within 100km of an already-chosen alert location
        too_close = any(haversine_km(lat, lon, slat, slon) < 100
                        for slat, slon in seen_coords)
        if too_close:
            continue
        seen_coords.append((lat, lon))

        # Reverse-geocode to get a zipcode
        try:
            rg = requests.get(
                f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}"
                f"&format=json&zoom=10",
                headers={"User-Agent": "QuickRadarArchive/1.0"}, timeout=15)
            rg.raise_for_status()
            rg_data = rg.json()
            addr = rg_data.get("address", {})
            zipcode = addr.get("postcode", "")
            city = addr.get("city") or addr.get("town") or addr.get("county") or "Unknown"
            if zipcode and re.match(r"^\d{5}$", zipcode):
                alert_locs.append((zipcode, city, f"Active {event}"))
        except Exception:
            pass

        if len(alert_locs) >= max_alerts:
            break

    return alert_locs


# ── Ollama model description (works for local and cloud models) ──────────────
def ollama_describe(image_bytes: bytes, model: str) -> str:
    """Send image to any Ollama model (local or cloud) and return its description."""
    try:
        from PIL import Image as PILImage
        img = PILImage.open(io.BytesIO(image_bytes))
        buf = io.BytesIO()
        img.convert("RGB").save(buf, format="PNG")
        img_b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
    except ImportError:
        img_b64 = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": CLOUD_PROMPT, "images": [img_b64]}],
        "stream": False,
    }
    resp = requests.post("http://localhost:11434/api/chat", json=payload, timeout=120)
    resp.raise_for_status()
    return resp.json().get("message", {}).get("content", "").strip()


# ── Save one image to the archive ────────────────────────────────────────────
def save_to_archive(run_dir, zipcode, station, city, image_bytes, url,
                    echo_category, echo_frac, echo_detail, gt, reason,
                    model_descriptions=None):
    images_dir = run_dir / "images"
    data_dir = run_dir / "data"
    vo_dir = run_dir / "voiceover"
    images_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(exist_ok=True)
    vo_dir.mkdir(exist_ok=True)

    stamp = run_dir.name  # e.g. "20260621_121012"
    safe_city = re.sub(r"[^\w]", "_", city)
    base = f"{zipcode}_{station['id']}_{safe_city}"

    # PNG
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(image_bytes))
        png_path = images_dir / f"{base}.png"
        img.convert("RGB").save(png_path)
    except ImportError:
        png_path = images_dir / f"{base}.gif"
        png_path.write_bytes(image_bytes)

    # JSON metadata
    meta = {
        "stamp": stamp,
        "run_dir": run_dir.name,
        "zipcode": zipcode,
        "city": city,
        "station_id": station["id"],
        "station_name": station["name"],
        "station_lat": station["lat"],
        "station_lon": station["lon"],
        "station_dist_km": round(station["dist_km"], 1),
        "radar_url": url,
        "capture_reason": reason,
        "echo_category": echo_category,
        "echo_fraction": echo_frac,
        "echo_pixel_detail": echo_detail,
        "nws_conditions": gt["conditions"],
        "nws_has_precip": gt["has_precip"],
        "nws_precip_description": gt["precip_description"],
        "nws_alerts": gt["alerts"],
        "nws_obs_station": gt["station_id"],
        "nws_obs_time": gt["obs_time"],
        "image_file": f"images/{png_path.name}",
        "voiceover_file": f"voiceover/{base}.txt",
        "voiceover_description": None,
        "model_descriptions": model_descriptions or {},
    }
    json_path = data_dir / f"{base}.json"
    json_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    # VoiceOver placeholder
    vo_path = vo_dir / f"{base}.txt"
    vo_path.write_text(
        f"# VoiceOver description for: {city} ({zipcode})\n"
        f"# NWS conditions: {gt['conditions']}\n"
        f"# Echo level: {echo_category}\n"
        f"# Alerts: {len(gt['alerts'])}\n"
        f"# Instructions: Open the images/ folder in the OneDrive app on your iPhone.\n"
        f"#   VoiceOver on, two-finger tap-and-hold on the image to get a description.\n"
        f"#   Copy the text and paste it below this line.\n\n",
        encoding="utf-8"
    )

    # Index entry (cumulative across all runs)
    index_path = ARCHIVE_DIR / "index.jsonl"
    with open(index_path, "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "stamp": stamp, "run_dir": run_dir.name, "zipcode": zipcode, "city": city,
            "station": station["id"], "echo_category": echo_category,
            "has_precip": gt["has_precip"], "has_alerts": len(gt["alerts"]) > 0,
            "reason": reason, "base": base,
        }) + "\n")

    return png_path, json_path


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Build radar image archive for test bed")
    parser.add_argument("--no-alerts", action="store_true",
                        help="Skip NWS alert hunting, only do geographic sweep")
    parser.add_argument("--label", action="store_true",
                        help="After capture, list archived images missing VoiceOver labels")
    parser.add_argument("--no-local", action="store_true",
                        help="Skip local model descriptions")
    parser.add_argument("--local-models", default=DEFAULT_LOCAL_MODELS,
                        help=f"Comma-separated local Ollama models to run (default: {DEFAULT_LOCAL_MODELS})")
    parser.add_argument("--no-cloud", action="store_true",
                        help="Skip cloud model descriptions (off by default; Ollama quota required)")
    parser.add_argument("--cloud-model", default=DEFAULT_CLOUD_MODEL,
                        help=f"Cloud vision model (default: {DEFAULT_CLOUD_MODEL}). "
                             f"Other options: gemma4:31b-cloud, minimax-m3:cloud")
    parser.add_argument("--output-dir", default=None,
                        help="Directory to save archive (default: archive/ next to this script). "
                             "Pass your OneDrive RadarData path to sync automatically.")
    args = parser.parse_args()

    global ARCHIVE_DIR
    if args.output_dir:
        ARCHIVE_DIR = Path(args.output_dir)
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    run_dir = ARCHIVE_DIR / "runs" / stamp
    run_dir.mkdir(parents=True, exist_ok=True)

    print(f"RADAR ARCHIVE BUILDER  —  {stamp}")
    print(f"Run folder: {run_dir.resolve()}")
    print()

    # Collect locations to process
    locations = []

    if not args.no_alerts:
        print("Checking NWS for active weather alerts...")
        alert_locs = alert_zipcodes(max_alerts=15)
        if alert_locs:
            print(f"  Found {len(alert_locs)} distinct alert areas:")
            for zc, city, reason in alert_locs:
                print(f"    {zc} {city} — {reason}")
            locations.extend(alert_locs)
        else:
            print("  No radar-relevant alerts active right now.")
        print()

    # Add geographic sweep (deduplicated against alert locations)
    alert_zips = {zc for zc, _, _ in locations}
    for zc, city in GEO_SWEEP:
        if zc not in alert_zips:
            locations.append((zc, city, "Geographic sweep"))

    print(f"Total locations to process: {len(locations)}")
    print()

    saved = []

    for i, (zipcode, city_hint, reason) in enumerate(locations, 1):
        is_alert = reason != "Geographic sweep"
        prefix = "[ALERT]" if is_alert else "      "
        print(f"{prefix} [{i}/{len(locations)}] {city_hint} ({zipcode})")

        # Geocode
        try:
            lat, lon, city = geocode(zipcode)
        except Exception as e:
            print(f"  geocode failed: {e}")
            continue

        # Find nearest radar station
        try:
            station = nearest_nexrad(lat, lon)
            if not station:
                print(f"  no radar station found")
                continue
            print(f"  station: {station['id']} ({station['name']}) {station['dist_km']:.0f}km")
        except Exception as e:
            print(f"  radar station lookup failed: {e}")
            continue

        # Download radar image
        try:
            image_bytes, url = download_radar(station["id"])
            if not image_bytes:
                print(f"  image download failed")
                continue
        except Exception as e:
            print(f"  download error: {e}")
            continue

        # Pixel analysis
        echo_cat, echo_frac, echo_detail = classify_echoes(image_bytes)
        print(f"  echoes: {echo_cat} ({echo_frac*100:.1f}% of map pixels)")

        # NWS ground truth
        try:
            gt = nws_ground_truth(lat, lon)
            alerts_str = f"{len(gt['alerts'])} alert(s)" if gt["alerts"] else "no alerts"
            print(f"  NWS: {gt['conditions'] or 'N/A'}  precip={'yes' if gt['has_precip'] else 'no'}  {alerts_str}")
        except Exception as e:
            gt = {"conditions": "", "has_precip": False, "precip_description": "",
                  "alerts": [], "station_id": "", "obs_time": "", "error": str(e)}
            print(f"  NWS error: {e}")

        # Model descriptions
        model_descriptions = {}
        local_models = [] if args.no_local else [m.strip() for m in args.local_models.split(",") if m.strip()]
        cloud_models = [] if args.no_cloud else [args.cloud_model]
        for model in local_models + cloud_models:
            print(f"  {model}...", end="", flush=True)
            try:
                desc = ollama_describe(image_bytes, model)
                model_descriptions[model] = desc
                print(f" done ({len(desc)} chars)")
            except Exception as e:
                print(f" failed: {e}")

        # Save to archive
        png_path, json_path = save_to_archive(
            run_dir, zipcode, station, city, image_bytes, url,
            echo_cat, echo_frac, echo_detail, gt, reason,
            model_descriptions=model_descriptions,
        )
        print(f"  → saved: images/{png_path.name}")
        saved.append({"zipcode": zipcode, "city": city, "echo": echo_cat,
                      "has_alerts": len(gt["alerts"]) > 0, "png": png_path})

    # Summary
    # Run summary JSON
    from collections import Counter
    cat_counts = Counter(r["echo"] for r in saved)
    run_summary = {
        "stamp": stamp,
        "run_dir": run_dir.name,
        "saved": len(saved),
        "locations_processed": len(locations),
        "flags": {
            "all": args.all,
            "no_alerts": args.no_alerts,
            "no_cloud": args.no_cloud,
            "cloud_model": None if args.no_cloud else args.cloud_model,
        },
        "echo_distribution": dict(cat_counts),
        "alert_captures": sum(1 for r in saved if r["has_alerts"]),
        "images": [
            {"zipcode": r["zipcode"], "city": r["city"],
             "echo": r["echo"], "has_alerts": r["has_alerts"]}
            for r in saved
        ],
    }
    (run_dir / "summary.json").write_text(json.dumps(run_summary, indent=2), encoding="utf-8")

    print(f"\n{'='*60}")
    print(f"CAPTURE COMPLETE")
    print(f"  Saved:   {len(saved)} images")
    print(f"  Run:     {run_dir.resolve()}")
    print()

    if saved:
        print("Echo distribution:")
        for cat, count in sorted(cat_counts.items()):
            print(f"  {cat:<10} {count}")
        print()

    # Count unlabeled VoiceOver files across all runs
    runs_dir = ARCHIVE_DIR / "runs"
    needs_label = []
    if runs_dir.exists():
        for txt in sorted(runs_dir.glob("*/voiceover/*.txt")):
            content = txt.read_text(encoding="utf-8")
            non_comment = [l for l in content.splitlines() if l.strip() and not l.startswith("#")]
            if not non_comment:
                needs_label.append(txt)

    this_run_unlabeled = [t for t in needs_label if run_dir.name in str(t)]
    if this_run_unlabeled:
        print(f"This run — {len(this_run_unlabeled)} images need VoiceOver labels:")
        for txt in this_run_unlabeled:
            print(f"  {txt.stem}")
        print()
        print("To label: open the images/ folder in OneDrive on your iPhone,")
        print("  VoiceOver on, two-finger tap-and-hold each image, copy the")
        print("  description, paste into the matching voiceover/*.txt file.")
        print()

    total_unlabeled = len(needs_label)
    if total_unlabeled > len(this_run_unlabeled):
        print(f"Total unlabeled across all runs: {total_unlabeled}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
