"""Saved-city storage.

The saved cities are an ordered mapping of display name -> [lat, lon],
persisted to ``city.json`` in the user-data directory. This mirrors the
original monolith's ``city_data`` dict and its three-tier load
(user file -> bundled default -> hardcoded defaults) exactly.
"""

import json
import os

from ..constants import DEFAULT_CITIES
from ..paths import bundled_file


class CityStore:
    """Ordered dict of display-name -> [lat, lon] with JSON persistence."""

    def __init__(self, city_file):
        self.city_file = city_file
        self.cities = {}

    # -- iteration / access ---------------------------------------------------
    def __contains__(self, name):
        return name in self.cities

    def __iter__(self):
        return iter(self.cities)

    def __len__(self):
        return len(self.cities)

    def names(self):
        return list(self.cities.keys())

    def coords(self, name):
        return self.cities[name]

    # -- mutation -------------------------------------------------------------
    def add(self, name, lat, lon):
        """Add a city; returns True if added, False if already present."""
        if name in self.cities:
            return False
        self.cities[name] = [lat, lon]
        self.save()
        return True

    def remove(self, name):
        if name in self.cities:
            del self.cities[name]
            self.save()

    def swap(self, i, j):
        """Swap two cities by position (used for move up/down)."""
        keys = list(self.cities.keys())
        if not (0 <= i < len(keys) and 0 <= j < len(keys)):
            return
        keys[i], keys[j] = keys[j], keys[i]
        self.cities = {k: self.cities[k] for k in keys}
        self.save()

    # -- persistence ----------------------------------------------------------
    def load(self):
        loaded = False
        # 1. User data file
        if os.path.exists(self.city_file):
            try:
                with open(self.city_file) as f:
                    data = json.load(f)
                    if data:
                        self.cities = data
                        loaded = True
            except Exception:
                pass

        # 2. Bundled / local default
        if not loaded:
            default_path = bundled_file("city.json")
            if default_path and os.path.exists(default_path):
                try:
                    with open(default_path) as f:
                        self.cities = json.load(f)
                        loaded = True
                except Exception:
                    pass

        # 3. Hardcoded fallback
        if not loaded:
            self.cities = DEFAULT_CITIES.copy()

        # Persist so the file exists next launch
        if not os.path.exists(self.city_file) and self.cities:
            self.save()

    def save(self):
        try:
            with open(self.city_file, "w") as f:
                json.dump(self.cities, f, indent=4)
        except Exception:
            pass
