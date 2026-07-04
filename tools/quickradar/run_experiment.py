#!/usr/bin/env python3
"""
run_experiment.py
=================

Batch runner for the QuickRadar experiment. Runs the full pipeline
(geocode → radar station → download image → zoom crop → Ollama description
→ current conditions → report) for a set of 10 zipcodes chosen to cover
diverse geography, radar station distances, and climate regions.

Each zipcode is run twice:
  1. Full radar image (no zoom) — the baseline.
  2. Zoomed to 100 km radius around the location — the experimental dial.

This lets us compare whether zooming in helps the model describe what's
relevant to the user's specific location vs. the full radar view.

Usage:
    python run_experiment.py
"""

import subprocess
import sys
import time
from pathlib import Path

# 10 zipcodes chosen for geographic and radar-coverage diversity.
# Each is annotated with the rationale for inclusion.
ZIPCODES = [
    # 1. Near radar station, Midwest, often active weather
    ("53718",  "Madison WI — close to KMKX radar (60km), Midwest convective"),
    # 2. Major coastal city, Southeast, hurricane/severe weather corridor
    ("33109",  "Miami Beach FL — coastal, SE radar coverage, tropical"),
    # 3. Plains, tornado alley, often active
    ("73072",  "Norman OK — Plains, tornado alley, close to KTLX radar"),
    # 4. Mountain West, far from radar, complex terrain
    ("80202",  "Denver CO — mountain west, terrain blockage risk"),
    # 5. Pacific Northwest, coastal, different radar network density
    ("98101",  "Seattle WA — PNW, coastal, sparse radar coverage"),
    # 6. Northeast corridor, dense radar coverage
    ("10001",  "New York NY — NE corridor, dense radar, urban"),
    # 7. Deep South, Gulf coast, convective weather
    ("39501",  "Gulfport MS — Gulf coast, tropical/maritime weather"),
    # 8. Desert Southwest, usually clear — tests "clear radar" descriptions
    ("85001",  "Phoenix AZ — desert SW, usually clear, distant radar"),
    # 9. Upper Midwest, lake-effect snow potential
    ("49855",  "Marquette MI — upper MI, lake-effect, remote radar"),
    # 10. Texas Gulf coast, severe weather frequency
    ("77002",  "Houston TX — Gulf coast TX, severe weather, convective"),
]


def run_one(zipcode: str, zoom: float | None, label: str) -> bool:
    """Run quickradar.py for one zipcode, optionally with zoom. Return success."""
    cmd = [sys.executable, "quickradar.py", zipcode]
    if zoom is not None:
        cmd += ["--zoom", str(zoom)]
    desc = f"{zipcode} ({label})"
    print(f"\n{'='*70}")
    print(f"  RUNNING: {desc}")
    print(f"{'='*70}")
    result = subprocess.run(cmd, timeout=600)
    if result.returncode != 0:
        print(f"  *** FAILED: {desc} (exit code {result.returncode}) ***")
        return False
    return True


def main() -> int:
    print("QUICKRADAR BATCH EXPERIMENT")
    print("=" * 70)
    print(f"Running {len(ZIPCODES)} zipcodes, each with full + zoomed radar")
    print(f"Total runs: {len(ZIPCODES) * 2}")
    print()

    results = []
    for zipcode, rationale in ZIPCODES:
        # Run 1: full radar (baseline)
        ok1 = run_one(zipcode, None, f"full radar — {rationale}")
        results.append((zipcode, "full", ok1))
        time.sleep(2)

        # Run 2: zoomed to 100km radius
        ok2 = run_one(zipcode, 100.0, f"zoom 100km — {rationale}")
        results.append((zipcode, "zoom100", ok2))
        time.sleep(2)

    # Summary
    print(f"\n\n{'='*70}")
    print("EXPERIMENT SUMMARY")
    print(f"{'='*70}\n")
    ok_count = sum(1 for _, _, ok in results if ok)
    fail_count = len(results) - ok_count
    print(f"Total runs:  {len(results)}")
    print(f"Succeeded:   {ok_count}")
    print(f"Failed:      {fail_count}")
    print()
    for zipcode, run_type, ok in results:
        status = "OK" if ok else "FAIL"
        print(f"  [{status}] {zipcode} {run_type}")

    print(f"\nReports saved as weather_<zipcode>_<timestamp>.txt")
    print(f"Radar images saved as radar_<zipcode>_<station>_<timestamp>.gif")
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())