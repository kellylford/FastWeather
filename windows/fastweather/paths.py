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


def user_data_dir():
    """Platform user-data directory (created if missing).

    Resolves to %APPDATA%/FastWeather on Windows, which matches what
    wx.StandardPaths.GetUserDataDir() returns once the app name is set. Kept
    wx-free so it is safe to call before (or without) a wx.App exists — calling
    wx.StandardPaths.Get() without an app hard-crashes on Windows.
    """
    base = (os.environ.get("APPDATA")
            or os.path.join(os.path.expanduser("~"), "AppData", "Roaming"))
    path = os.path.join(base, "FastWeather")
    if not os.path.exists(path):
        try:
            os.makedirs(path)
        except Exception:
            pass
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
