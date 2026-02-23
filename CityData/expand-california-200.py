#!/usr/bin/env python3
"""
Expands California from 200 to 300 cities in us-cities-cached.json
using the OpenStreetMap Overpass API.
Merges new cities in, preserving existing order.
Auto-distributes to all platform locations when done.
"""

import json
import time
import shutil
import requests
from pathlib import Path

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
TARGET = 300
STATE = "California"

ROOT = Path(__file__).parent.parent
CACHE_FILE = ROOT / "us-cities-cached.json"
DIST_PATHS = [
    ROOT / "webapp" / "us-cities-cached.json",
    ROOT / "FastWeatherMac" / "us-cities-cached.json",
    ROOT / "iOS" / "FastWeather" / "Resources" / "us-cities-cached.json",
    ROOT / "iOS" / "us-cities-cached.json",
]


def query_cities(state_name: str, retries: int = 4) -> list[dict]:
    query = f"""
[out:json][timeout:60];
area["name"="{state_name}"]["admin_level"="4"]["boundary"="administrative"]->.state;
(
  node["place"~"^(city|town|village|hamlet)$"]["name"](area.state);
);
out body;
"""
    headers = {
        "User-Agent": "FastWeather CacheBuilder/2.0 (github.com/FastWeather)",
        "Content-Type": "application/x-www-form-urlencoded",
    }
    delay = 10
    for attempt in range(retries):
        try:
            resp = requests.post(OVERPASS_URL, data={"data": query}, headers=headers, timeout=90)
            if resp.status_code in (429, 503):
                wait = delay * (2 ** attempt)
                print(f"  ⏳ Rate limited, waiting {wait}s...")
                time.sleep(wait)
                continue
            resp.raise_for_status()
            elements = resp.json().get("elements", [])
            results = []
            for el in elements:
                tags = el.get("tags", {})
                name = tags.get("name", "").strip()
                if not name:
                    continue
                pop_str = tags.get("population", "0").replace(",", "")
                try:
                    population = int(pop_str)
                except ValueError:
                    population = 0
                results.append({
                    "name": name,
                    "lat": el["lat"],
                    "lon": el["lon"],
                    "population": population,
                    "place_type": tags.get("place", ""),
                })
            return results
        except Exception as e:
            wait = delay * (2 ** attempt)
            print(f"  ⚠️  Error (attempt {attempt+1}): {e} — retrying in {wait}s")
            time.sleep(wait)
    return []


def main():
    with open(CACHE_FILE) as f:
        data = json.load(f)

    existing = data.get(STATE, [])
    print(f"California: {len(existing)} cities currently → expanding to {TARGET} (+{TARGET - len(existing)} needed)")

    existing_names = {c["name"].lower() for c in existing}

    print(f"  Querying Overpass API...")
    candidates = query_cities(STATE)
    print(f"  Got {len(candidates)} candidates from API")

    # Sort by population desc, then city/town type preference
    type_rank = {"city": 0, "town": 1, "village": 2, "hamlet": 3}
    candidates.sort(key=lambda c: (-c["population"], type_rank.get(c["place_type"], 99)))

    added = 0
    for c in candidates:
        if len(existing) >= TARGET:
            break
        if c["name"].lower() in existing_names:
            continue
        existing.append({
            "name": c["name"],
            "state": STATE,
            "country": "United States",
            "lat": round(c["lat"], 7),
            "lon": round(c["lon"], 7),
        })
        existing_names.add(c["name"].lower())
        added += 1

    data[STATE] = existing
    print(f"  Added {added} cities → California now has {len(existing)}")

    with open(CACHE_FILE, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"  💾 Saved {CACHE_FILE}")

    print("\nDistributing to all platforms...")
    for dest in DIST_PATHS:
        if dest.parent.exists():
            shutil.copy2(CACHE_FILE, dest)
            print(f"  ✓ {dest.relative_to(ROOT)}")
        else:
            print(f"  ✗ Skipped (dir missing): {dest.relative_to(ROOT)}")

    total = sum(len(v) for v in data.values())
    print(f"\n✅ Done. Total US cities: {total}")


if __name__ == "__main__":
    main()
