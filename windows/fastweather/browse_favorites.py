"""Persisted favorite regions (US states / countries) for the Browse dialog."""

import json
import os

from .paths import user_data_dir


def _path():
    return os.path.join(user_data_dir(), "browse_favorites.json")


def load():
    """Return a list of {'kind': 'us'|'intl', 'region': name}."""
    try:
        with open(_path(), encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    except Exception:
        pass
    return []


def save(favorites):
    try:
        with open(_path(), "w", encoding="utf-8") as f:
            json.dump(favorites, f, indent=2)
    except Exception:
        pass


def is_favorite(favorites, kind, region):
    return any(f.get("kind") == kind and f.get("region") == region for f in favorites)


def toggle(favorites, kind, region):
    """Add or remove a favorite; returns the new list and the resulting state."""
    if is_favorite(favorites, kind, region):
        favorites = [f for f in favorites
                     if not (f.get("kind") == kind and f.get("region") == region)]
        return favorites, False
    favorites = favorites + [{"kind": kind, "region": region}]
    return favorites, True
