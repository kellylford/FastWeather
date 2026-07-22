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
