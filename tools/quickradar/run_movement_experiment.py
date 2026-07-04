#!/usr/bin/env python3
"""
run_movement_experiment.py
==========================

Two-frame movement experiment: download the NWS RIDGE animated radar loop,
extract the first and last frames (~1 hour apart), send both to the vision
model, and ask whether the precipitation has moved.

This tests the biggest gap found in the QuickRadar experiment: a single
static image cannot tell you if a storm is moving toward you. By sending
two frames and asking the model to compare, we test whether the AI can
infer movement direction — the "is it coming at me?" question.

Usage:
    python run_movement_experiment.py
"""

import base64
import io
import sys
import time
from datetime import datetime
from pathlib import Path

import requests
from PIL import Image

try:
    import ollama
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False

NWS_HEADERS = {"User-Agent": "QuickRadar/1.0 (weather-app research)"}

# Zipcodes from the storm chase that had active weather
STORM_ZIPCODES = [
    ("32424", "FL Panhandle — squall line"),
    ("31999", "Columbus GA — rain and fog"),
    ("36345", "SE Alabama — light rain"),
    ("31774", "S Georgia — active precip in radar field"),
    ("73072", "Norman OK — heavy cells in radar field"),
    ("39501", "Gulfport MS — storm band"),
]

MOVEMENT_PROMPT = (
    "You are looking at two weather radar images of the same area, taken "
    "approximately one hour apart. The first image is the earlier frame, "
    "the second is the most recent.\n\n"
    "Please compare the two images and describe:\n"
    "  - Has the precipitation moved? If so, in which direction (north, "
    "south, east, west, northeast, etc.)?\n"
    "  - Has the precipitation intensified (more red/orange) or weakened "
    "(less color, more green or clear)?\n"
    "  - Have any storm cells formed, dissipated, or changed shape?\n"
    "  - Has the overall coverage area of precipitation grown or shrunk?\n"
    "  - Based on the change between the two frames, is precipitation "
    "approaching or moving away from the center of the image?\n\n"
    "Be specific and factual. If you cannot determine movement, say so. "
    "If the images appear identical, say that."
)


def geocode_zipcode(zipcode: str) -> dict:
    url = f"https://api.zippopotam.us/us/{zipcode}"
    resp = requests.get(url, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    place = data["places"][0]
    return {
        "lat": float(place["latitude"]),
        "lon": float(place["longitude"]),
        "city": place["place name"],
        "state": place["state"],
    }


def haversine_km(lat1, lon1, lat2, lon2):
    import math
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dlam/2)**2
    return 2 * R * math.asin(math.sqrt(a))


def find_nearest_nexrad(lat, lon):
    url = "https://api.weather.gov/radar/stations"
    resp = requests.get(url, headers={
        "Accept": "application/geo+json",
        "User-Agent": "QuickRadar/1.0"
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
            best = {
                "id": sid,
                "name": props.get("name", "Unknown"),
                "lat": st_lat,
                "lon": st_lon,
                "distance_km": d,
            }
    return best


def download_and_extract_frames(station_id: str) -> tuple:
    """Download the NWS RIDGE animated loop and extract first/last frames.

    Returns (first_frame_png_bytes, last_frame_png_bytes, frame_count).
    """
    sid = station_id.upper()
    url = f"https://radar.weather.gov/ridge/standard/{sid}_loop.gif"
    resp = requests.get(url, headers=NWS_HEADERS, timeout=30)
    resp.raise_for_status()

    # Open as animated GIF
    img = Image.open(io.BytesIO(resp.content))
    frame_count = getattr(img, "n_frames", 1)
    if frame_count < 2:
        # Can't do movement comparison with only 1 frame
        return None, None, frame_count

    # Extract first and last frames, convert to PNG for the model
    img.seek(0)
    first = img.convert("RGBA")
    first_png = io.BytesIO()
    first.save(first_png, format="PNG")
    first_bytes = first_png.getvalue()

    img.seek(frame_count - 1)
    last = img.convert("RGBA")
    last_png = io.BytesIO()
    last.save(last_png, format="PNG")
    last_bytes = last_png.getvalue()

    return first_bytes, last_bytes, frame_count


def describe_movement(first_bytes, last_bytes, model, ollama_url):
    """Send two radar frames to Ollama and ask about movement."""
    first_b64 = base64.b64encode(first_bytes).decode("utf-8")
    last_b64 = base64.b64encode(last_bytes).decode("utf-8")

    if HAS_OLLAMA:
        client_kwargs = {}
        if ollama_url != "http://localhost:11434":
            client_kwargs["host"] = ollama_url
        client = ollama.Client(**client_kwargs) if client_kwargs else ollama
        response = client.chat(
            model=model,
            messages=[{
                "role": "user",
                "content": MOVEMENT_PROMPT,
                "images": [first_b64, last_b64],
            }],
        )
        return response["message"]["content"], _extract_tokens(response)
    else:
        url = ollama_url.rstrip("/") + "/api/chat"
        payload = {
            "model": model,
            "messages": [{
                "role": "user",
                "content": MOVEMENT_PROMPT,
                "images": [first_b64, last_b64],
            }],
            "stream": False,
        }
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

    print("TWO-FRAME MOVEMENT EXPERIMENT")
    print("=" * 70)
    print(f"Model: {model}")
    print(f"Testing {len(STORM_ZIPCODES)} locations with active weather")
    print()

    results = []
    for zipcode, desc in STORM_ZIPCODES:
        print(f"\n{'='*70}")
        print(f"  {zipcode} — {desc}")
        print(f"{'='*70}")

        # Geocode
        try:
            geo = geocode_zipcode(zipcode)
            print(f"  Location: {geo['city']}, {geo['state']}")
        except Exception as e:
            print(f"  ERROR geocoding: {e}")
            results.append((zipcode, False, "geocode error"))
            continue

        # Find radar station
        try:
            station = find_nearest_nexrad(geo["lat"], geo["lon"])
            print(f"  Radar: {station['id']} ({station['name']}), {station['distance_km']:.1f} km")
        except Exception as e:
            print(f"  ERROR finding station: {e}")
            results.append((zipcode, False, "station error"))
            continue

        # Download and extract frames
        print(f"  Downloading radar loop for {station['id']}...")
        try:
            first_bytes, last_bytes, frame_count = download_and_extract_frames(station["id"])
        except Exception as e:
            print(f"  ERROR downloading loop: {e}")
            results.append((zipcode, False, "download error"))
            continue

        if first_bytes is None:
            print(f"  Only {frame_count} frame(s) — cannot compare movement")
            results.append((zipcode, False, f"only {frame_count} frame"))
            continue

        print(f"  Extracted {frame_count} frames from loop GIF")
        print(f"  First frame: {len(first_bytes)} bytes, Last frame: {len(last_bytes)} bytes")

        # Save frames for reference
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        Path(f"frame1_{zipcode}_{stamp}.png").write_bytes(first_bytes)
        Path(f"frame2_{zipcode}_{stamp}.png").write_bytes(last_bytes)

        # Send to model
        print(f"  Sending two frames to {model}...")
        try:
            description, tokens = describe_movement(first_bytes, last_bytes, model, ollama_url)
            print(f"  -> description received ({tokens.get('total_tokens', '?')} tokens)")
            print()
            print("  MOVEMENT DESCRIPTION:")
            print("  " + description.replace("\n", "\n  "))
        except Exception as e:
            print(f"  ERROR from Ollama: {e}")
            description = f"[ERROR: {e}]"
            results.append((zipcode, False, "ollama error"))
            continue

        # Save report
        report_path = Path(f"movement_{zipcode}_{stamp}.txt")
        sep = "=" * 70
        report = "\n".join([
            sep, "TWO-FRAME MOVEMENT REPORT", sep, "",
            f"Zipcode:      {zipcode}",
            f"Location:     {geo['city']}, {geo['state']}",
            f"Radar station: {station['id']} — {station['name']}",
            f"Frames:        {frame_count} (first + last compared)",
            f"Model:         {model}",
            f"Generated:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "-" * 70,
            "MOVEMENT COMPARISON (AI description of two frames ~1 hour apart)",
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

    # Summary
    print(f"\n\n{'='*70}")
    print("MOVEMENT EXPERIMENT SUMMARY")
    print(f"{'='*70}\n")
    ok = sum(1 for _, s, _ in results if s)
    print(f"Total: {len(results)}  OK: {ok}  Fail: {len(results)-ok}")
    for zc, success, note in results:
        print(f"  [{'OK' if success else 'FAIL'}] {zc} — {note}")


if __name__ == "__main__":
    main()