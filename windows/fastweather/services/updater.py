"""In-app auto-update via GitHub Releases (mirrors QuickMail's update feed).

Checks the repository's latest release, compares its tag to the running
version, and — when newer — downloads the installer asset and launches it. The
app then exits so the per-user installer can replace files without elevation.
Only meaningful for the frozen build; from source it is a no-op check.
"""

import os
import re
import tempfile

from .. import __version__
from . import http

GITHUB_REPO = "kellylford/FastWeather"
LATEST_RELEASE_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"


def _version_tuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "")) or (0,)


def is_newer(latest, current):
    a, b = _version_tuple(latest), _version_tuple(current)
    n = max(len(a), len(b))
    a += (0,) * (n - len(a))  # zero-pad so 1.1 and 1.1.0 compare equal
    b += (0,) * (n - len(b))
    return a > b


def check_for_update(current_version=None):
    """Return {'version', 'url', 'notes'} if a newer release exists, else None.

    Raises on network/API failure so a manual check can report "couldn't check".
    """
    current = current_version or __version__
    data = http.get_json(LATEST_RELEASE_URL)
    tag = (data.get("tag_name") or "").lstrip("v")
    if not tag or not is_newer(tag, current):
        return None
    url = None
    for asset in data.get("assets", []):
        name = (asset.get("name") or "").lower()
        if name.endswith("setup.exe"):
            url = asset.get("browser_download_url")
            break
    return {"version": tag, "url": url, "notes": data.get("body") or ""}


def download_installer(url, progress=None):
    """Download the installer to a temp file; return its path.

    ``progress`` (optional) is called with (downloaded_bytes, total_bytes).
    """
    resp = http.session().get(url, stream=True, timeout=120)
    resp.raise_for_status()
    total = int(resp.headers.get("Content-Length") or 0)
    name = os.path.basename(url) or "WeatherFast-Setup.exe"
    path = os.path.join(tempfile.gettempdir(), name)
    done = 0
    with open(path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=65536):
            if chunk:
                f.write(chunk)
                done += len(chunk)
                if progress:
                    progress(done, total)
    return path


def launch_installer(path):
    """Launch the downloaded installer (Windows).

    The installer is downloaded over HTTPS from the project's GitHub release
    assets. Note it is not yet code-signed, so Windows SmartScreen may prompt.
    """
    os.startfile(path)  # noqa: S606
