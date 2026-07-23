"""Thread-safe in-memory cache with per-entry TTL.

Workers read/write concurrently, so access is guarded by a lock. Mirrors the
intent of the iOS TTLCache (short-lived current data, longer-lived derived data).
"""

import threading
import time


class TTLCache:
    def __init__(self, default_ttl=600):
        self.default_ttl = default_ttl
        self._store = {}  # key -> (expires_at, value)
        self._lock = threading.Lock()

    def get(self, key):
        """Return the cached value, or None if missing/expired."""
        with self._lock:
            entry = self._store.get(key)
            if not entry:
                return None
            expires_at, value = entry
            if time.monotonic() >= expires_at:
                del self._store[key]
                return None
            return value

    def set(self, key, value, ttl=None):
        ttl = self.default_ttl if ttl is None else ttl
        with self._lock:
            self._store[key] = (time.monotonic() + ttl, value)

    def clear(self):
        with self._lock:
            self._store.clear()
