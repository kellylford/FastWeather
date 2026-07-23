"""Loads the bundled pre-geocoded city caches for state/country browsing.

``us-cities-cached.json``   -> {state -> [ {name, state, country, lat, lon}, ... ]}
``international-cities-cached.json`` -> {country -> [ {...}, ... ]}
"""

import json
import os

from .paths import bundle_dir


def _candidate_paths(filename):
    base = bundle_dir()
    repo_root = os.path.dirname(base)  # windows/ -> repo root (dev only)
    return [
        os.path.join(base, filename),
        os.path.join(base, "webapp", filename),
        os.path.join(repo_root, "webapp", filename),
    ]


def _load_first(filename):
    for path in _candidate_paths(filename):
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    print(f"Loaded city cache from {path}")
                    return data
            except Exception as e:
                print(f"Error loading city cache from {path}: {e}")
    return None


def load_cached_cities():
    """Return (us_cities_cache, intl_cities_cache); either may be None."""
    us = _load_first("us-cities-cached.json")
    intl = _load_first("international-cities-cached.json")
    return us, intl


def flatten_cities(us_cache, intl_cache):
    """Flatten the state/country caches into one list of city dicts.

    Each entry: {name, display, lat, lon, region}. Used by the Directional
    Explorer to search cities along a bearing.
    """
    out = []
    for cache, region_is_country in ((us_cache, False), (intl_cache, True)):
        if not cache:
            continue
        for region, cities in cache.items():
            for c in cities:
                try:
                    lat = float(c["lat"])
                    lon = float(c["lon"])
                except (KeyError, TypeError, ValueError):
                    continue
                name = c.get("name", "")
                state = c.get("state", "")
                country = c.get("country", region if region_is_country else "")
                parts = [p for p in [name, state, country] if p]
                out.append({
                    "name": name,
                    "display": ", ".join(parts),
                    "lat": lat,
                    "lon": lon,
                    "region": region,
                })
    return out
