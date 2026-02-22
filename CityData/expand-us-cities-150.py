#!/usr/bin/env python3
"""
Expands us-cities-cached.json from 100 to 150 cities per state using the
OpenStreetMap Overpass API. Merges new cities into the existing cache rather
than replacing, so existing ranked order is preserved.

Output: us-cities-cached.json (merged in-place, saves progress after each state)
"""

import json
import time
import requests
from pathlib import Path

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

TARGET_PER_STATE = 150

US_STATES = [
    "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
    "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho",
    "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana",
    "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi",
    "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
    "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma",
    "Oregon", "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota",
    "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington",
    "West Virginia", "Wisconsin", "Wyoming",
]


def query_cities_for_state(state_name: str, retries: int = 4) -> list[dict]:
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
                print(f"  ⏳ Rate limited ({resp.status_code}), waiting {wait}s before retry {attempt+1}/{retries}...")
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
        except requests.exceptions.HTTPError as e:
            wait = delay * (2 ** attempt)
            print(f"  ⚠️  HTTP error for {state_name} (attempt {attempt+1}): {e} — retrying in {wait}s")
            time.sleep(wait)
        except Exception as e:
            print(f"  ⚠️  Overpass error for {state_name}: {e}")
            return []
    print(f"  ❌ Giving up on {state_name} after {retries} attempts")
    return []


def rank_cities(cities: list[dict]) -> list[dict]:
    type_rank = {"city": 0, "town": 1, "village": 2, "hamlet": 3}
    return sorted(
        cities,
        key=lambda c: (
            type_rank.get(c["place_type"], 9),
            -c["population"],
            c["name"],
        ),
    )


def main():
    output_file = Path(__file__).parent / "us-cities-cached.json"
    root_file = Path(__file__).parent.parent / "us-cities-cached.json"

    if not output_file.exists():
        print(f"❌ Cache file not found: {output_file}")
        return

    with open(output_file, "r", encoding="utf-8") as f:
        cached_data = json.load(f)

    existing_total = sum(len(v) for v in cached_data.values())
    print(f"Loaded existing cache: {existing_total} cities across {len(cached_data)} states")
    print(f"Target: {TARGET_PER_STATE} per state ({TARGET_PER_STATE * 50} total)\n")

    total = len(US_STATES)
    added_total = 0

    for idx, state in enumerate(US_STATES, 1):
        existing = cached_data.get(state, [])
        if len(existing) >= TARGET_PER_STATE:
            print(f"[{idx}/{total}] {state}: already has {len(existing)} — skipping")
            continue

        needed = TARGET_PER_STATE - len(existing)
        print(f"[{idx}/{total}] {state}: has {len(existing)}, need {needed} more — querying Overpass...", flush=True)

        raw = query_cities_for_state(state)
        print(f"  → {len(raw)} raw results from Overpass")

        if not raw:
            print(f"  ⚠️  No results; keeping existing {len(existing)} entries")
            time.sleep(1)
            continue

        # Build a set of names already in cache (case-insensitive)
        existing_names = {c["name"].lower() for c in existing}

        # Rank all Overpass results, filter out names we already have
        ranked = rank_cities(raw)
        new_candidates = [
            c for c in ranked
            if c["name"].lower() not in existing_names
        ]

        # Take as many as we need, convert to cache schema
        new_entries = []
        for c in new_candidates[:needed]:
            new_entries.append({
                "name": c["name"],
                "state": state,
                "country": "United States",
                "lat": round(c["lat"], 7),
                "lon": round(c["lon"], 7),
            })

        merged = existing + new_entries
        cached_data[state] = merged
        added_total += len(new_entries)
        print(f"  ✓ Added {len(new_entries)}, now {len(merged)} cities for {state}")

        # Save after every state
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(cached_data, f, indent=2, ensure_ascii=False)

        # Also keep root copy in sync
        if root_file.exists():
            with open(root_file, "w", encoding="utf-8") as f:
                json.dump(cached_data, f, indent=2, ensure_ascii=False)

        if idx < total:
            time.sleep(5)

    total_cities = sum(len(v) for v in cached_data.values())
    print(f"\n✅ Done! Added {added_total} new cities.")
    print(f"Total: {total_cities} cities across {len(cached_data)} states")

    # Distribute to iOS bundle
    ios_file = Path(__file__).parent.parent / "iOS" / "FastWeather" / "Resources" / "us-cities-cached.json"
    mac_file = Path(__file__).parent.parent / "FastWeatherMac" / "us-cities-cached.json"
    webapp_file = Path(__file__).parent.parent / "webapp" / "us-cities-cached.json"

    for dest in [ios_file, mac_file, webapp_file]:
        if dest.exists():
            with open(dest, "w", encoding="utf-8") as f:
                json.dump(cached_data, f, indent=2, ensure_ascii=False)
            print(f"  → Distributed to {dest}")

    print(f"\nOutput: {output_file.resolve()}")


if __name__ == "__main__":
    main()
