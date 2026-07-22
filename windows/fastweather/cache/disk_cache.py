"""On-disk JSON cache with timestamp/staleness metadata.

Stores ``{"timestamp": epoch, "payload": ...}`` under a subdirectory of the
cache dir. Used for offline resilience and long-lived data (historical,
reverse-geocoded place names). Mirrors iOS CachedWeather's age/isStale intent.
"""

import hashlib
import json
import os
import time

from ..paths import cache_dir


class DiskCache:
    def __init__(self, namespace, max_age=86400):
        self.dir = os.path.join(cache_dir(), namespace)
        self.max_age = max_age
        if not os.path.exists(self.dir):
            try:
                os.makedirs(self.dir)
            except Exception:
                pass

    def _path(self, key):
        digest = hashlib.sha1(key.encode("utf-8")).hexdigest()
        return os.path.join(self.dir, f"{digest}.json")

    def get(self, key, max_age=None):
        """Return payload if present and not older than max_age, else None."""
        path = self._path(key)
        if not os.path.exists(path):
            return None
        try:
            with open(path, "r", encoding="utf-8") as f:
                entry = json.load(f)
        except Exception:
            return None
        age = time.time() - entry.get("timestamp", 0)
        limit = self.max_age if max_age is None else max_age
        if limit is not None and age > limit:
            return None
        return entry.get("payload")

    def age(self, key):
        """Age in seconds of a cached entry, or None if absent."""
        path = self._path(key)
        if not os.path.exists(path):
            return None
        try:
            with open(path, "r", encoding="utf-8") as f:
                entry = json.load(f)
        except Exception:
            return None
        return time.time() - entry.get("timestamp", 0)

    def set(self, key, payload):
        try:
            with open(self._path(key), "w", encoding="utf-8") as f:
                json.dump({"timestamp": time.time(), "payload": payload}, f)
        except Exception:
            pass
