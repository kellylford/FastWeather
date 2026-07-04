#!/usr/bin/env python3
"""One-off diagnostic: why does Storm Approach's headline direction differ from
the Weather Around Me tiles/summary for east-side Madison at 150 miles?

Replicates BOTH surfaces with live data:
  A. Storm Approach improved ring (fixed 20/40/70 km radii) — the headline
  B. RegionalWeatherService directional tiles at the picker distance
     (lat/lon +/- miles/69 degrees) + the view's generateRegionalSummary logic
"""
import importlib.util
import math
import sys

import os
spec = importlib.util.spec_from_file_location(
    "ndt", os.path.join(os.path.dirname(os.path.abspath(__file__)), "nowcast_data_test.py"))
ndt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ndt)

LAT, LON = 43.0870, -89.3120   # east side Madison, WI (approx)
DIST_MILES = 150.0

repo = ndt.find_repo()
key = ndt.load_api_key(repo)
base = ndt.om_base(key)
pool = ndt.load_city_pools(repo)

# ---- A. Storm Approach (the headline) --------------------------------------
import time
now = time.time()
saved = ndt.pseudo_saved_cities(pool, LAT, LON)
saved_keys = {"%.2f,%.2f" % (s["lat"], s["lon"]) for s in saved}
towns = ndt.nearby_towns(pool, LAT, LON, saved_keys)
samples = ndt.ring_samples(LAT, LON, improved=True)
coords = ([(s["lat"], s["lon"]) for s in samples] +
          [(t["lat"], t["lon"]) for t in towns])
url = ndt.om_url(base, {
    "latitude": ",".join("%.6f" % c[0] for c in coords),
    "longitude": ",".join("%.6f" % c[1] for c in coords),
    "minutely_15": "precipitation", "current": "precipitation,weather_code",
    "timeformat": "unixtime", "timezone": "GMT", "forecast_days": "2"}, key)
fx = ndt.http_get_json(url)
n = len(samples)
steering = ndt.steering_wind(base, key, LAT, LON)
sa = ndt.analyse_storm_approach(samples, fx[:n], now, True, steering,
                                towns, fx[n:], [], [], None)
print("A. STORM APPROACH (headline card) — ring radii 20/40/70 km (max ~43 mi),")
print("   INDEPENDENT of the 150-mile distance picker")
print("   Headline: %s" % ndt.storm_headline(sa))
if sa["nearest"]:
    print("   Nearest active precip: %.0f km (%.0f mi) at bearing %.0f (%s), %.2f mm/15min"
          % (sa["nearest"][0], sa["nearest"][0]*0.621371, sa["nearest"][1],
             ndt.cardinal_name(sa["nearest"][1]), sa["nearest"][2]))
print("   Ring active points: %d of 48; motion: %s conf=%s"
      % (sa["ring_active"],
         ("toward %s at %.0f km/h" % (ndt.cardinal_name(sa["motion"]["toward"]),
                                      sa["motion"]["speed_kmh"])) if sa["motion"] else "none",
         sa["confidence"]))
for line in ndt.place_lines(sa):
    print("   Town: %s" % line)

# ---- B. WAM directional tiles at 150 miles ----------------------------------
print()
print("B. WEATHER AROUND ME tiles at %.0f miles (RegionalWeatherService)" % DIST_MILES)
d = DIST_MILES / 69.0   # milesToDegrees — RegionalWeatherService.swift:45
tiles = [("North",      LAT + d, LON),
         ("Northeast",  LAT + d, LON + d),
         ("East",       LAT,     LON + d),
         ("Southeast",  LAT - d, LON + d),
         ("South",      LAT - d, LON),
         ("Southwest",  LAT - d, LON - d),
         ("West",       LAT,     LON - d),
         ("Northwest",  LAT + d, LON - d)]
url = ndt.om_url(base, {
    "latitude": ",".join("%.6f" % t[1] for t in [("C", LAT, LON)] + tiles),
    "longitude": ",".join("%.6f" % t[2] for t in [("C", LAT, LON)] + tiles),
    "current": "temperature_2m,precipitation,weather_code"}, key)
tf = ndt.http_get_json(url)
centre_t = tf[0]["current"]
precip_dirs, warmer, colder = [], [], []
for (name, tlat, tlon), r in zip(tiles, tf[1:]):
    cur = r["current"]
    code = cur.get("weather_code")
    desc = ndt.WEATHER_CODE_DESC.get(code, "?")
    actual_mi = ndt.haversine_km(LAT, LON, tlat, tlon) * 0.621371
    print("   %-10s %5.0f mi actual | %-22s | %.1f C | precip %.2f mm"
          % (name, actual_mi, desc, cur.get("temperature_2m", 0), cur.get("precipitation") or 0))
    low = desc.lower()
    if "rain" in low or "snow" in low:
        precip_dirs.append(name.lower())
    ct = centre_t.get("temperature_2m", 0)
    if cur.get("temperature_2m", 0) > ct + 5: warmer.append(name.lower())
    if cur.get("temperature_2m", 0) < ct - 5: colder.append(name.lower())

# generateRegionalSummary (WeatherAroundMeView) reproduction
summary = []
if warmer: summary.append("Warmer to the " + ", ".join(warmer))
if colder: summary.append("Colder to the " + ", ".join(colder))
if precip_dirs: summary.append("Precipitation to the " + ", ".join(precip_dirs))
print()
print("   Regional Summary card would say: %s"
      % (". ".join(summary) if summary else "Similar conditions in all directions"))
print()
print("   NOTE: tile conditions in the app are WeatherKit-overlaid; this uses")
print("   Open-Meteo codes, so tile wording may differ slightly from the app.")
