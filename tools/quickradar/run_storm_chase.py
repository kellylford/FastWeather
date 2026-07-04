#!/usr/bin/env python3
"""Storm chase: run QuickRadar for 10 zipcodes near active weather."""
import subprocess, sys, time

STORM_ZIPCODES = [
    ("31774", "Severe Tstorm — S Georgia (Irwin County)"),
    ("76934", "Severe Tstorm — W Texas (Ballinger/Runnels)"),
    ("32424", "Severe Tstorm — FL Panhandle (Gulf County)"),
    ("31999", "Flash Flood — W Georgia (Columbus)"),
    ("67152", "Flash Flood — S Kansas (Sumner County)"),
    ("36345", "Flash Flood — SE Alabama (Headland/Dothan)"),
    ("74401", "Spec Weather — E Oklahoma (Muskogee)"),
    ("31567", "Spec Weather — S Georgia (Coffee County)"),
    ("62901", "Flood Warning — S Illinois (Carbondale)"),
    ("75961", "Flood Warning — E Texas (Nacogdoches)"),
]

def run_one(zipcode, zoom, label):
    cmd = [sys.executable, "quickradar.py", zipcode]
    if zoom is not None:
        cmd += ["--zoom", str(zoom)]
    print(f"\n{'='*70}")
    print(f"  STORM CHASE: {zipcode} ({label}) zoom={'full' if zoom is None else zoom}")
    print(f"{'='*70}")
    result = subprocess.run(cmd, timeout=600)
    return result.returncode == 0

results = []
for zipcode, rationale in STORM_ZIPCODES:
    ok1 = run_one(zipcode, None, f"full — {rationale}")
    results.append((zipcode, "full", ok1))
    time.sleep(2)
    ok2 = run_one(zipcode, 100.0, f"zoom100 — {rationale}")
    results.append((zipcode, "zoom100", ok2))
    time.sleep(2)

print(f"\n\n{'='*70}\nSTORM CHASE SUMMARY\n{'='*70}\n")
ok = sum(1 for _,_,o in results if o)
print(f"Total: {len(results)}  OK: {ok}  Fail: {len(results)-ok}")
for zc, rt, o in results:
    print(f"  [{'OK' if o else 'FAIL'}] {zc} {rt}")
