"""Filesystem path resolution for bundled data and user data.

Bundled JSON (city.json, us/international-cities-cached.json) currently lives in
the ``windows/`` directory (parent of this package) when running from source,
and in ``sys._MEIPASS`` when frozen by PyInstaller. User data (city.json,
config.json, caches) lives under the platform user-data directory.
"""

import os
import sys


def bundle_dir():
    """Directory containing bundled data files.

    Frozen: PyInstaller's _MEIPASS. Source: the ``windows/`` directory that is
    the parent of this ``fastweather`` package.
    """
    if getattr(sys, "frozen", False):
        return sys._MEIPASS
    # this file: windows/fastweather/paths.py -> up two -> windows/
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bundled_file(name):
    """Absolute path to a bundled data file by name."""
    return os.path.join(bundle_dir(), name)


APP_DIR_NAME = "WeatherFast"
_LEGACY_DIR_NAME = "FastWeather"  # pre-rename; migrated once on first run


def _appdata_base():
    return (os.environ.get("APPDATA")
            or os.path.join(os.path.expanduser("~"), "AppData", "Roaming"))


def _migrate_legacy(new_path):
    """One-time copy of saved data from the old FastWeather folder.

    Runs only when the new WeatherFast folder has no city.json yet but the old
    folder exists, so an existing user's cities/settings carry over unchanged.
    """
    if os.path.exists(os.path.join(new_path, "city.json")):
        return
    old_path = os.path.join(_appdata_base(), _LEGACY_DIR_NAME)
    if not os.path.isdir(old_path) or old_path == new_path:
        return
    import shutil
    for name in ("city.json", "config.json", "browse_favorites.json"):
        src = os.path.join(old_path, name)
        if os.path.exists(src):
            try:
                shutil.copy2(src, os.path.join(new_path, name))
            except Exception:
                pass
    old_cache = os.path.join(old_path, "cache")
    new_cache = os.path.join(new_path, "cache")
    if os.path.isdir(old_cache) and not os.path.exists(new_cache):
        try:
            shutil.copytree(old_cache, new_cache)
        except Exception:
            pass


def user_data_dir():
    """Platform user-data directory (created if missing).

    Resolves to %APPDATA%/WeatherFast on Windows. Kept wx-free so it is safe to
    call before (or without) a wx.App exists — calling wx.StandardPaths.Get()
    without an app hard-crashes on Windows. On first run it migrates data from
    the legacy %APPDATA%/FastWeather folder.
    """
    path = os.path.join(_appdata_base(), APP_DIR_NAME)
    if not os.path.exists(path):
        try:
            os.makedirs(path)
        except Exception:
            pass
    _migrate_legacy(path)
    return path


def cache_dir():
    """Directory for on-disk caches (created if missing)."""
    path = os.path.join(user_data_dir(), "cache")
    if not os.path.exists(path):
        try:
            os.makedirs(path)
        except Exception:
            pass
    return path
