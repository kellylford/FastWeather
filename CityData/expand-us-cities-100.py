#!/usr/bin/env python3
"""
Expands us-cities-cached.json to 100 cities per state using the OpenStreetMap
Overpass API. One HTTP call per state returns lat/lon directly — no secondary
geocoding needed — so the whole job completes in ~10 minutes respecting a 1 s
delay between state queries.

Output: us-cities-cached.json (overwrites existing file with expanded data)
"""

import json
import time
import requests
from pathlib import Path
from country_names import normalize_country

# Overpass API endpoint
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

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

TARGET_PER_STATE = 100

def query_cities_for_state(state_name: str, retries: int = 4) -> list[dict]:
    """
    Query Overpass for all cities/towns/villages in a US state.
    Retries with exponential backoff on 429/503 errors.
    Returns list of dicts with name, lat, lon, population (optional).
    """
    # Query for populated place nodes in the state tagged with the state name
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
    delay = 10  # start with 10s backoff on rate-limit
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
    """
    Sort by place type priority (city > town > village > hamlet) then by
    population descending, then alphabetically for stability.
    Place type order gives natural importance ranking when pop data is sparse.
    """
    type_rank = {"city": 0, "town": 1, "village": 2, "hamlet": 3}
    return sorted(
        cities,
        key=lambda c: (
            type_rank.get(c["place_type"], 9),
            -c["population"],
            c["name"],
        ),
    )


def deduplicate(cities: list[dict]) -> list[dict]:
    """Remove entries with identical names (case-insensitive)."""
    seen = set()
    out = []
    for c in cities:
        key = c["name"].lower()
        if key not in seen:
            seen.add(key)
            out.append(c)
    return out


def main():
    output_file = Path("us-cities-cached.json")

    # Load existing cache to preserve already-done states on resume
    if output_file.exists():
        with open(output_file, "r", encoding="utf-8") as f:
            cached_data = json.load(f)
        print(f"Loaded existing cache: {sum(len(v) for v in cached_data.values())} cities across {len(cached_data)} states")
    else:
        cached_data = {}

    total = len(US_STATES)
    for idx, state in enumerate(US_STATES, 1):
        existing = cached_data.get(state, [])
        if len(existing) >= TARGET_PER_STATE:
            print(f"[{idx}/{total}] {state}: already has {len(existing)} cities — skipping")
            continue

        print(f"[{idx}/{total}] {state}: querying Overpass...", flush=True)
        raw = query_cities_for_state(state)
        print(f"  → {len(raw)} raw results from Overpass")

        if not raw:
            # No results — keep whatever we had
            print(f"  ⚠️  No results; keeping existing {len(existing)} entries")
            time.sleep(1)
            continue

        ranked = rank_cities(raw)
        deduped = deduplicate(ranked)

        # Build final cache entries (match existing schema)
        state_cities = []
        for c in deduped[:TARGET_PER_STATE]:
            state_cities.append({
                "name": c["name"],
                "state": state,
                "country": "United States",
                "lat": round(c["lat"], 7),
                "lon": round(c["lon"], 7),
            })

        cached_data[state] = state_cities
        print(f"  ✓ Saved {len(state_cities)} cities for {state}")

        # Save after every state so progress is not lost on interruption
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(cached_data, f, indent=2, ensure_ascii=False)

        # 5 seconds between state queries to stay well under Overpass rate limits
        if idx < total:
            time.sleep(5)

    total_cities = sum(len(v) for v in cached_data.values())
    print(f"\n✅ Done! {total_cities} cities across {len(cached_data)} states")
    print(f"Output: {output_file.resolve()}")


if __name__ == "__main__":
    main()
