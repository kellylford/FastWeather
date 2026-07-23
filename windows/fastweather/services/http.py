"""Shared HTTP helpers: a single requests session with a descriptive User-Agent.

A descriptive User-Agent is required by Nominatim and NWS (api.weather.gov
rejects requests without one). Kept here so every service shares the policy.
"""

import requests

from ..constants import DEFAULT_TIMEOUT, USER_AGENT

_session = None


def session():
    global _session
    if _session is None:
        _session = requests.Session()
        _session.headers.update({"User-Agent": USER_AGENT})
    return _session


def get_json(url, params=None, headers=None, timeout=DEFAULT_TIMEOUT):
    """GET a URL and return parsed JSON, raising on HTTP error."""
    resp = session().get(url, params=params, headers=headers, timeout=timeout)
    resp.raise_for_status()
    return resp.json()
