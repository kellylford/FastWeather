#!/usr/bin/env python3
"""
run_velocity_experiment.py
==========================

Storm structure experiment: download NWS RIDGE higher-tilt reflectivity
images (products 2-3, which show storm structure at higher elevation angles)
and ask the vision model to identify features associated with severe
weather — storm cells, hook echoes, and organized structure.

NOTE: True Doppler velocity images (N0V/N0U products) are NOT available
via the free NWS RIDGE static URL path. They require the NWS LDM feed or
a specialized service. The IEM tile service does not serve velocity tiles
either. This is a real limitation of the free data ecosystem.

However, the higher-tilt reflectivity products (products 2-3) show storm
*structure* at mid-levels, which can reveal:
  - Hook echoes (a notch in the reflectivity pattern, often associated
    with rotation)
  - Storm cell organization
  - Bounded weak echo regions (BWERs)
  - Storm tilt

This experiment tests whether the model can identify these structural
features from the available free images — a proxy for the velocity
rotation detection we'd ideally run.

Usage:
    python run_velocity_experiment.py
"""

import base64
import math
import sys
import time
from datetime import datetime
from pathlib import Path

import requests

try:
    import ollama
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False

NWS_HEADERS = {"User-Agent": "QuickRadar/1.0 (weather-app research)"}

# Use the same storm-chase zipcodes — these had active weather
STORM_ZIPCODES = [
    ("32424", "FL Panhandle — squall line"),
    ("31999", "Columbus GA — rain and fog"),
    ("36345", "SE Alabama — light rain"),
    ("31774", "S Georgia — active precip"),
    ("73072", "Norman OK — heavy cells"),
    ("39501", "Gulfport MS — storm band"),
]

VELOCITY_PROMPT = (
    "You are looking at a weather radar reflectivity image taken at a "
    "higher elevation angle (mid-levels of the storm). This shows the "
    "internal structure of storm cells, not just the precipitation at "
    "ground level.\n\n"
    "Please describe:\n"
    "  - The overall storm structure. Are storms organized (lines, "
    "clusters) or scattered?\n"
    "  - Can you identify any hook echoes? A hook echo is a curved notch "
    "or hook-shaped appendage on the right-rear flank of a storm cell, "
    "often associated with rotation and tornadoes.\n"
    "  - Are there any bounded weak echo regions (holes in the "
    "reflectivity surrounded by strong echoes)? These indicate strong "
    "updrafts.\n"
    "  - Do any storm cells show a tilted or asymmetric structure?\n"
    "  - Based on the structure visible, is there any indication of "
    "severe weather potential?\n\n"
    "Be specific and factual. If you see no concerning features, say "
    "'no severe weather signatures visible.' If you see possible hook "
    "echoes or rotation signatures, describe their location clearly."
)


def geocode_zipcode(zipcode):
    url = f"https://api.zippopotam.us/us/{zipcode}"
    resp = requests.get(url, timeout=15)
    resp.raise_for_status()
    place = resp.json()["places"][0]
    return {"lat": float(place["latitude"]), "lon": float(place["longitude"]),
            "city": place["place name"], "state": place["state"]}


def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dlam/2)**2
    return 2 * R * math.asin(math.sqrt(a))


def find_nearest_nexrad(lat, lon):
    url = "https://api.weather.gov/radar/stations"
    resp = requests.get(url, headers={
        "Accept": "application/geo+json", "User-Agent": "QuickRadar/1.0"
    }, timeout=20)
    resp.raise_for_status()
    features = resp.json().get("features", [])
    best, best_dist = None, None
    for st in features:
        coords = st.get("geometry", {}).get("coordinates")
        if not coords or len(coords) < 2:
            continue
        props = st.get("properties", {})
        sid = props.get("id", "").upper()
        if not sid.startswith("K"):
            continue
        st_lon, st_lat = coords[0], coords[1]
        d = haversine_km(lat, lon, st_lat, st_lon)
        if best_dist is None or d < best_dist:
            best_dist = d
            best = {"id": sid, "name": props.get("name", "Unknown"),
                    "lat": st_lat, "lon": st_lon, "distance_km": d}
    return best


def download_velocity_image(station_id, out_path):
    """Download a higher-tilt reflectivity image for storm structure analysis.

    NWS RIDGE products 2-3 are higher-elevation tilts that show mid-level
    storm structure. True velocity products (N0V/N0U) are not available via
    free static URLs — see the module docstring for details.
    """
    sid = station_id.upper()
    # Try product 2 first (higher tilt, shows more structure), then 3
    for product_num in ["2", "3"]:
        url = f"https://radar.weather.gov/ridge/standard/{sid}_{product_num}.gif"
        try:
            resp = requests.get(url, headers=NWS_HEADERS, timeout=20)
            if resp.status_code == 200 and len(resp.content) > 1000:
                out_path.write_bytes(resp.content)
                return url
        except requests.RequestException:
            continue
    return None


def describe_velocity(image_path, model, ollama_url):
    with open(image_path, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode("utf-8")

    if HAS_OLLAMA:
        client_kwargs = {}
        if ollama_url != "http://localhost:11434":
            client_kwargs["host"] = ollama_url
        client = ollama.Client(**client_kwargs) if client_kwargs else ollama
        response = client.chat(
            model=model,
            messages=[{"role": "user", "content": VELOCITY_PROMPT, "images": [img_b64]}],
        )
        return response["message"]["content"], _extract_tokens(response)
    else:
        url = ollama_url.rstrip("/") + "/api/chat"
        payload = {"model": model, "stream": False,
                   "messages": [{"role": "user", "content": VELOCITY_PROMPT, "images": [img_b64]}]}
        resp = requests.post(url, json=payload, timeout=300)
        resp.raise_for_status()
        data = resp.json()
        return data["message"]["content"], _extract_tokens(data)


def _extract_tokens(response):
    return {
        "prompt_eval_count": response.get("prompt_eval_count"),
        "eval_count": response.get("eval_count"),
        "total_tokens": (response.get("prompt_eval_count", 0) or 0) +
                        (response.get("eval_count", 0) or 0) if response.get("eval_count") else None,
    }


def main():
    model = "gemma4:31b-cloud"
    ollama_url = "http://localhost:11434"

    print("VELOCITY IMAGE EXPERIMENT — TORNADO ROTATION DETECTION")
    print("=" * 70)
    print(f"Model: {model}")
    print(f"Testing {len(STORM_ZIPCODES)} locations with active weather")
    print()

    results = []
    for zipcode, desc in STORM_ZIPCODES:
        print(f"\n{'='*70}")
        print(f"  {zipcode} — {desc}")
        print(f"{'='*70}")

        try:
            geo = geocode_zipcode(zipcode)
            print(f"  Location: {geo['city']}, {geo['state']}")
        except Exception as e:
            print(f"  ERROR geocoding: {e}")
            results.append((zipcode, False, "geocode error"))
            continue

        try:
            station = find_nearest_nexrad(geo["lat"], geo["lon"])
            print(f"  Radar: {station['id']} ({station['name']}), {station['distance_km']:.1f} km")
        except Exception as e:
            print(f"  ERROR finding station: {e}")
            results.append((zipcode, False, "station error"))
            continue

        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        img_path = Path(f"velocity_{zipcode}_{station['id']}_{stamp}.gif")
        print(f"  Downloading velocity image for {station['id']}...")
        img_url = download_velocity_image(station["id"], img_path)
        if img_url is None:
            print(f"  ERROR: velocity image not available for {station['id']}")
            results.append((zipcode, False, "no velocity image"))
            continue
        print(f"  -> saved {img_path.name} ({img_path.stat().st_size} bytes)")

        print(f"  Sending velocity image to {model}...")
        try:
            description, tokens = describe_velocity(img_path, model, ollama_url)
            print(f"  -> description received ({tokens.get('total_tokens', '?')} tokens)")
            print()
            print("  VELOCITY DESCRIPTION:")
            print("  " + description.replace("\n", "\n  "))
        except Exception as e:
            print(f"  ERROR from Ollama: {e}")
            results.append((zipcode, False, "ollama error"))
            continue

        # Save report
        report_path = Path(f"velocity_{zipcode}_{stamp}.txt")
        sep = "=" * 70
        report = "\n".join([
            sep, "VELOCITY IMAGE REPORT — TORNADO ROTATION DETECTION", sep, "",
            f"Zipcode:       {zipcode}",
            f"Location:      {geo['city']}, {geo['state']}",
            f"Radar station: {station['id']} — {station['name']}",
            f"Station dist:  {station['distance_km']:.1f} km",
            f"Image file:    {img_path.name} ({img_path.stat().st_size} bytes)",
            f"Image URL:     {img_url}",
            f"Model:         {model}",
            f"Generated:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "-" * 70,
            "VELOCITY IMAGE DESCRIPTION (via Ollama)",
            "-" * 70,
            "",
            description.strip(),
            "",
            "-" * 70,
            "TOKEN USAGE",
            "-" * 70,
            "",
            f"  Prompt tokens: {tokens.get('prompt_eval_count', 'N/A')}",
            f"  Output tokens: {tokens.get('eval_count', 'N/A')}",
            f"  Total tokens:  {tokens.get('total_tokens', 'N/A')}",
            "",
            sep, "END OF REPORT", sep,
        ])
        report_path.write_text(report, encoding="utf-8")
        print(f"\n  Report: {report_path.name}")
        results.append((zipcode, True, "OK"))
        time.sleep(2)

    print(f"\n\n{'='*70}")
    print("VELOCITY EXPERIMENT SUMMARY")
    print(f"{'='*70}\n")
    ok = sum(1 for _, s, _ in results if s)
    print(f"Total: {len(results)}  OK: {ok}  Fail: {len(results)-ok}")
    for zc, success, note in results:
        print(f"  [{'OK' if success else 'FAIL'}] {zc} — {note}")


if __name__ == "__main__":
    main()