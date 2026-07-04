#!/usr/bin/env python3
"""
Quick model comparison against saved archive images.
Usage: python compare_models.py [run_dir]
       run_dir defaults to the most recent run in OneDrive RadarData.
"""
import base64
import io
import json
import sys
import time
from pathlib import Path

import requests
from PIL import Image

ONEDRIVE_RUNS = Path.home() / "Library/CloudStorage/OneDrive-Personal/RadarData/runs"

MODELS = ["minicpm-v4.6", "qwen2.5vl:3b", "qwen3-vl:2b"]

PROMPT = """You are describing a NWS NEXRAD radar image for a blind user. Be accurate and specific.

COLORS:
  SOLID BLUE/CYAN/TEAL = bodies of water (NOT precipitation)
  WHITE/LIGHT GRAY = no precipitation
  GREEN = light rain  YELLOW = moderate  ORANGE = heavy  RED = very heavy  PINK = extreme
  THIN RED/BROWN LINES = county/state borders (NOT storm outlines)
  TOP STRIP BOXES = legend reference only, not active warnings

Answer these three questions:
1. Is there precipitation visible on the map? If yes: where and what intensity?
2. Are any warning polygons drawn ON the map (not the legend strip at top)?
3. Overall: mostly clear or active weather?"""


def b64_png(path):
    img = Image.open(path)
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def ask(b64, model):
    t0 = time.time()
    r = requests.post("http://localhost:11434/api/chat", json={
        "model": model,
        "messages": [{"role": "user", "content": PROMPT, "images": [b64]}],
        "stream": False,
    }, timeout=120)
    r.raise_for_status()
    return r.json()["message"]["content"].strip(), round(time.time() - t0, 1)


def main():
    if len(sys.argv) > 1:
        run_dir = Path(sys.argv[1])
    else:
        runs = sorted(ONEDRIVE_RUNS.iterdir()) if ONEDRIVE_RUNS.exists() else []
        if not runs:
            print("No runs found. Run the archive builder first.")
            sys.exit(1)
        run_dir = runs[-1]

    images_dir = run_dir / "images"
    data_dir = run_dir / "data"
    images = sorted(images_dir.glob("*.png"))

    print(f"Run: {run_dir.name}  ({len(images)} images)")
    print(f"Models: {', '.join(MODELS)}")

    timings = {m: [] for m in MODELS}

    for img_path in images:
        json_path = data_dir / (img_path.stem + ".json")
        gt = json.loads(json_path.read_text()) if json_path.exists() else {}
        city = gt.get("city", img_path.stem)
        nws = gt.get("nws_conditions") or "N/A"
        echo = gt.get("echo_category", "?")
        alerts = len(gt.get("nws_alerts", []))

        print(f"\n{'='*65}")
        print(f"  {city} ({gt.get('zipcode','?')})  |  NWS: {nws}  |  echo: {echo}  |  alerts: {alerts}")
        print(f"{'='*65}")

        b64 = b64_png(img_path)
        for model in MODELS:
            try:
                desc, t = ask(b64, model)
                timings[model].append(t)
                print(f"\n  [{model}]  {t}s")
                for line in desc.split("\n"):
                    if line.strip():
                        print(f"    {line}")
            except Exception as e:
                print(f"\n  [{model}]  ERROR: {e}")

    print(f"\n\n{'='*65}")
    print("TIMING SUMMARY")
    print(f"{'='*65}")
    for model in MODELS:
        ts = timings[model]
        if ts:
            print(f"  {model:<25}  avg {sum(ts)/len(ts):.1f}s  min {min(ts):.1f}s  max {max(ts):.1f}s")


if __name__ == "__main__":
    main()
