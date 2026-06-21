#!/usr/bin/env python3
"""
run_saved_comparison.py
=======================

Runs multiple vision models against the SAME set of already-downloaded radar
images, so results are directly comparable (same pixel, same moment, same
NWS ground truth).

Designed to answer: does the model choice matter, and how much?

Usage:
    # Compare all available models against images from a specific experiment run
    python run_saved_comparison.py --summary experiment_summary_20260621_060823.txt

    # Or specify image files directly
    python run_saved_comparison.py --images radar_53703_*.gif radar_60601_*.gif

    # Override which models to test
    python run_saved_comparison.py --summary experiment_summary_*.txt \
        --models minicpm-v4.6 moondream granite3.2-vision qwen2.5vl:3b

The script reads NWS ground truth from the experiment summary file (so it
does not need to re-hit the NWS API) and produces a per-model, per-image
accuracy table plus a top-level summary.
"""

import argparse
import base64
import glob
import io
import json
import re
import sys
import time
from pathlib import Path
from datetime import datetime, timezone

import requests

# ── Models to compare (can be overridden via --models) ──────────────────────
DEFAULT_MODELS = [
    "minicpm-v4.6",
    "moondream",
    "granite3.2-vision",
    "qwen2.5vl:3b",
]

# ── Prompt (same for all models so results are comparable) ──────────────────
PROMPT = """You are describing a NWS NEXRAD base-reflectivity radar image for a blind user. Be accurate and specific.

COLORS — learn these before describing anything:
  SOLID BLUE, CYAN, or TEAL filled areas = BODIES OF WATER (Great Lakes, rivers, coastlines). These are NOT precipitation. They are permanent map features.
  WHITE or LIGHT GRAY areas = NO precipitation detected.
  LIGHT GREEN = very light rain/drizzle.
  GREEN = light rain.
  YELLOW = moderate rain.
  ORANGE = heavy rain.
  RED or DARK RED = very heavy rain or large hail.
  PINK or MAGENTA = ice or extreme precipitation.

LINES — do not confuse these with weather:
  THIN RED or BROWN LINES = county and state borders. NOT storm outlines.

TOP OF IMAGE — warning legend strip:
  The very top of the image has a row of colored boxes (Tornado Warning, Severe Thunderstorm Warning, Flash Flood Warning, etc.). These are a LEGEND KEY — they show what color would be used IF a warning existed. Do not report a warning just because you see these colored boxes. Only report a warning if you see a colored polygon or outlined shape drawn ON the MAP itself, below the legend strip.

WHAT TO DESCRIBE:
1. Is there any precipitation visible on the map (green/yellow/orange/red/pink areas)? If yes: where is it, what intensity, roughly how large an area?
2. Are any colored polygons or warning outlines drawn ON the map area (not the top legend strip)?
3. Is the map mostly clear or active?
Answer each of these three questions. Be brief and factual."""

NWS_HEADERS = {"User-Agent": "QuickRadar/1.0 (weather-app research; contact: local)"}


# ── Image → PNG base64 ───────────────────────────────────────────────────────
def image_to_png_b64(image_path: Path) -> str:
    try:
        from PIL import Image
        img = Image.open(image_path)
        buf = io.BytesIO()
        img.convert("RGB").save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("utf-8")
    except ImportError:
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")


# ── Call Ollama ──────────────────────────────────────────────────────────────
def describe_image(image_path: Path, model: str, prompt: str) -> tuple[str, dict]:
    """Return (description, token_info)."""
    img_b64 = image_to_png_b64(image_path)
    url = "http://localhost:11434/api/chat"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt, "images": [img_b64]}],
        "stream": False,
    }
    resp = requests.post(url, json=payload, timeout=300)
    resp.raise_for_status()
    data = resp.json()
    desc = data.get("message", {}).get("content", "")
    token_info = {
        "prompt_eval_count": data.get("prompt_eval_count"),
        "eval_count": data.get("eval_count"),
        "eval_duration_ns": data.get("eval_duration"),
    }
    return desc, token_info


# ── Heuristic scoring (same as run_minicpm_experiment.py) ───────────────────
def score(has_precip_gt: bool | None, has_alerts_gt: bool, description: str) -> dict:
    desc = description.lower()

    # Precipitation signal
    precip_pos = any(kw in desc for kw in [
        "precipitation", "rain", "shower", "storm", "drizzle", "snow", "hail",
        "green", "yellow", "orange", "red", "light rain", "moderate", "heavy",
    ])
    precip_neg = any(kw in desc for kw in [
        "no precipitation", "no rain", "mostly clear", "map is clear",
        "map area is clear", "no precip", "clear map", "clear radar",
        "no detected precipitation", "no echo", "appears clear",
        "map appears clear", "no active precipitation",
        "no green", "no yellow", "no orange", "no red",
    ])
    ai_precip = precip_pos and not precip_neg

    # Warning signal
    warn_pos = any(kw in desc for kw in [
        "warning polygon", "active warning", "warning is active",
        "active tornado", "tornado warning active", "polygon drawn",
        "warning drawn on the map", "warning on the map",
        "outlined polygon", "colored polygon",
    ])
    warn_neg = any(kw in desc for kw in [
        "no active warning", "no warning polygon", "no warning",
        "no tornado", "legend only", "legend key", "no polygon",
        "not active", "reference only", "no colored polygon",
        "only in the top legend", "top legend",
    ])
    ai_warn = warn_pos and not warn_neg

    precip_correct = None if has_precip_gt is None else (ai_precip == has_precip_gt)
    warn_correct = ai_warn == has_alerts_gt

    return {
        "ai_claims_precip": ai_precip,
        "ai_claims_warning": ai_warn,
        "precip_correct": precip_correct,
        "warning_correct": warn_correct,
    }


# ── Parse experiment summary to extract ground truth ─────────────────────────
def parse_summary_ground_truth(summary_path: Path) -> dict:
    """
    Parse ground truth from a run_minicpm_experiment summary file.
    Returns {zipcode: {city, has_precip, has_alerts, conditions, precip_desc}}.
    """
    text = summary_path.read_text(encoding="utf-8")
    results = {}
    # Lines like:  "  Madison WI                   no         no    ✓         no        no    ✓"
    # But we need the raw zip → city mapping from LOCATIONS list,
    # and GT columns from the table. Easier: parse the full descriptions section.
    #
    # Pattern: "--- City (zipcode) ---\nNWS: <cond>  |  precip: <pd>  |  alerts: <n>"
    pattern = re.compile(
        r"--- (.+?) \((\d+)\) ---\s*\nNWS: (.*?)  \|  precip: (.*?)  \|  alerts: (\d+)"
    )
    for m in pattern.finditer(text):
        city, zipcode, cond, precip_desc, alert_count = m.groups()
        has_precip = precip_desc.strip() not in ("none", "", "N/A")
        results[zipcode] = {
            "city": city.strip(),
            "conditions": cond.strip(),
            "precip_description": precip_desc.strip(),
            "has_precip": has_precip,
            "has_alerts": int(alert_count) > 0,
        }
    return results


# ── Match image file → zipcode ───────────────────────────────────────────────
def image_zipcode(image_path: Path) -> str | None:
    """Extract zipcode from filename like radar_53703_KMKX_20260621_055953.gif"""
    m = re.match(r"radar_(\d{5})_", image_path.name)
    return m.group(1) if m else None


# ── Main ─────────────────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser(description="Compare multiple models on saved radar images")
    parser.add_argument("--summary", default=None,
                        help="Experiment summary file to read ground truth from. "
                             "Defaults to the most recent experiment_summary_*.txt")
    parser.add_argument("--images", nargs="*", default=None,
                        help="Radar image files to test. Defaults to all radar_*.gif "
                             "files matching the summary timestamp.")
    parser.add_argument("--models", nargs="+", default=DEFAULT_MODELS,
                        help=f"Models to compare (default: {' '.join(DEFAULT_MODELS)})")
    parser.add_argument("--ollama-url", default="http://localhost:11434")
    args = parser.parse_args()

    # Find summary file
    if args.summary:
        summary_path = Path(args.summary)
    else:
        candidates = sorted(glob.glob("experiment_summary_*.txt"), reverse=True)
        if not candidates:
            print("No experiment_summary_*.txt found. Run run_minicpm_experiment.py first.")
            return 1
        summary_path = Path(candidates[0])
    print(f"Ground truth from: {summary_path}")
    ground_truth = parse_summary_ground_truth(summary_path)
    print(f"  Found ground truth for {len(ground_truth)} locations")

    # Find image files
    if args.images:
        image_files = [Path(p) for p in args.images]
    else:
        # Match by timestamp prefix of summary file
        stamp = summary_path.stem.split("_", 2)[-1]  # e.g. 20260621_060823
        date_prefix = stamp[:8]  # e.g. 20260621
        image_files = sorted(Path(".").glob(f"radar_*_{date_prefix}_*.gif"))

    if not image_files:
        print("No radar image files found. Check --images or run the experiment first.")
        return 1
    print(f"Images to test: {len(image_files)}")

    # Filter to images where we have ground truth
    testable = []
    for img in image_files:
        zc = image_zipcode(img)
        if zc and zc in ground_truth:
            testable.append((img, zc, ground_truth[zc]))
        else:
            print(f"  skipping {img.name} (no ground truth for zipcode {zc})")
    print(f"Testable: {len(testable)}  Models: {len(args.models)}")
    print()

    # Run models
    # results[model][zipcode] = {description, score, token_info, error}
    results = {m: {} for m in args.models}

    for model in args.models:
        print(f"\n{'='*60}")
        print(f"MODEL: {model}")
        print(f"{'='*60}")

        for img_path, zipcode, gt in testable:
            city = gt["city"]
            print(f"  {city} ({zipcode}) ... ", end="", flush=True)
            try:
                desc, token_info = describe_image(img_path, model, PROMPT)
                sc = score(gt["has_precip"], gt["has_alerts"], desc)
                p_mark = "✓" if sc["precip_correct"] else ("✗" if sc["precip_correct"] is False else "?")
                w_mark = "✓" if sc["warning_correct"] else "✗"
                gen_s = (token_info.get("eval_duration_ns") or 0) / 1e9
                print(f"precip={p_mark}  warn={w_mark}  ({gen_s:.1f}s)")
                results[model][zipcode] = {
                    "description": desc,
                    "score": sc,
                    "token_info": token_info,
                    "error": None,
                }
            except Exception as e:
                print(f"ERROR: {e}")
                results[model][zipcode] = {"description": "", "score": {}, "token_info": {}, "error": str(e)}
            time.sleep(1)

    # ── Summary table ────────────────────────────────────────────────────────
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = Path(f"model_comparison_{stamp}.txt")

    lines = [
        "=" * 70,
        "MULTI-MODEL RADAR DESCRIPTION COMPARISON",
        "=" * 70,
        f"Models compared: {', '.join(args.models)}",
        f"Images tested:   {len(testable)}",
        f"Ran at:          {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        f"Ground truth:    {summary_path.name}",
        "",
    ]

    # Per-model accuracy
    lines += ["-" * 70, "ACCURACY BY MODEL", "-" * 70, ""]
    for model in args.models:
        p_right = sum(1 for zc, _, gt in testable
                      if results[model].get(zc, {}).get("score", {}).get("precip_correct"))
        p_total = sum(1 for zc, _, gt in testable
                      if results[model].get(zc, {}).get("score", {}).get("precip_correct") is not None)
        w_right = sum(1 for zc, _, gt in testable
                      if results[model].get(zc, {}).get("score", {}).get("warning_correct"))
        w_total = len(testable)
        p_pct = f"{100*p_right//p_total}%" if p_total else "N/A"
        w_pct = f"{100*w_right//w_total}%" if w_total else "N/A"
        lines.append(f"  {model:<30}  precip {p_right}/{p_total} ({p_pct})  "
                     f"  warn {w_right}/{w_total} ({w_pct})")
    lines.append("")

    # Per-location table
    lines += ["-" * 70, "PER-LOCATION RESULTS (P=precip ✓/✗, W=warn ✓/✗)", "-" * 70, ""]
    header = f"  {'Location':<22} {'GT P':>5} {'GT W':>5}"
    for m in args.models:
        short = m.split(":")[0][-10:]
        header += f"  {short:>12}"
    lines.append(header)
    lines.append("  " + "-" * (22 + 10 + len(args.models) * 14))

    for img_path, zipcode, gt in testable:
        city = gt["city"]
        gt_p = "yes" if gt["has_precip"] else "no"
        gt_w = "yes" if gt["has_alerts"] else "no"
        row = f"  {city:<22} {gt_p:>5} {gt_w:>5}"
        for model in args.models:
            r = results[model].get(zipcode, {})
            sc = r.get("score", {})
            if r.get("error"):
                cell = "     ERR"
            else:
                p = "✓" if sc.get("precip_correct") else ("✗" if sc.get("precip_correct") is False else "?")
                w = "✓" if sc.get("warning_correct") else "✗"
                ai_p = "y" if sc.get("ai_claims_precip") else "n"
                ai_w = "y" if sc.get("ai_claims_warning") else "n"
                cell = f" P{p}({ai_p}) W{w}({ai_w})"
            row += f"  {cell:>12}"
        lines.append(row)

    lines.append("")

    # Full descriptions
    lines += ["=" * 70, "FULL AI DESCRIPTIONS BY LOCATION", "=" * 70, ""]
    for img_path, zipcode, gt in testable:
        city = gt["city"]
        lines.append(f"{'─'*60}")
        lines.append(f"{city} ({zipcode})  |  NWS: {gt['conditions']}  "
                     f"|  precip: {gt['precip_description'] or 'none'}  "
                     f"|  alerts: {'yes' if gt['has_alerts'] else 'no'}")
        lines.append("")
        for model in args.models:
            r = results[model].get(zipcode, {})
            lines.append(f"  [{model}]")
            if r.get("error"):
                lines.append(f"    ERROR: {r['error']}")
            else:
                for ln in (r.get("description") or "").strip().splitlines():
                    lines.append(f"    {ln}")
            lines.append("")

    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n\nComparison written to: {out_path.resolve()}")

    # Print accuracy table to console
    print("\nACCURACY SUMMARY:")
    for model in args.models:
        p_right = sum(1 for zc, _, _ in testable
                      if results[model].get(zc, {}).get("score", {}).get("precip_correct"))
        p_total = sum(1 for zc, _, _ in testable
                      if results[model].get(zc, {}).get("score", {}).get("precip_correct") is not None)
        w_right = sum(1 for zc, _, _ in testable
                      if results[model].get(zc, {}).get("score", {}).get("warning_correct"))
        w_total = len(testable)
        print(f"  {model:<30}  precip {p_right}/{p_total}   warn {w_right}/{w_total}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
