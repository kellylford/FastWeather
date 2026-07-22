"""Device location.

Tries the Windows Runtime Geolocator when the ``winsdk`` package is present and
the OS grants permission; otherwise falls back to opt-in IP-based geolocation
over HTTPS. Returns a place dict {name, lat, lon, source}. This is only ever
invoked from an explicit user action ("Add My Location").
"""

from . import http

_IP_LOOKUP_URL = "https://ipapi.co/json/"


def _try_windows_location():
    """Best-effort Windows Runtime Geolocator; returns (lat, lon) or None."""
    try:
        import asyncio
        from winsdk.windows.devices.geolocation import Geolocator
    except Exception:
        return None
    try:
        geolocator = Geolocator()

        async def _get():
            pos = await geolocator.get_geoposition_async()
            c = pos.coordinate
            return c.latitude, c.longitude

        return asyncio.run(_get())
    except Exception:
        return None


def _ip_location():
    data = http.get_json(_IP_LOOKUP_URL)
    lat = data.get("latitude")
    lon = data.get("longitude")
    if lat is None or lon is None:
        raise RuntimeError("IP geolocation returned no coordinates")
    city = data.get("city", "")
    region = data.get("region", "")
    country = data.get("country_name", "")
    name = ", ".join(p for p in [city, region, country] if p) or f"{lat:.2f}, {lon:.2f}"
    return {"name": name, "lat": float(lat), "lon": float(lon), "source": "IP"}


def get_location(allow_ip=True):
    """Return {name, lat, lon, source}. Raises if location can't be determined."""
    coords = _try_windows_location()
    if coords is not None:
        lat, lon = coords
        # Reverse-geocode a friendly name (throttled + cached).
        from . import geocoding_service
        name = geocoding_service.reverse_geocode(lat, lon)
        return {"name": name, "lat": lat, "lon": lon, "source": "GPS"}
    if not allow_ip:
        raise RuntimeError("Precise location unavailable and IP lookup disabled")
    return _ip_location()
