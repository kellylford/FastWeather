#!/usr/bin/env python3
"""
run_minicpm_experiment.py
=========================

Multi-location accuracy experiment for minicpm-v4.6 on NWS radar images.

For each of 20 US zipcodes:
  1. Pre-check NWS current conditions to know ground truth (has precipitation? active alerts?).
  2. Download the NEXRAD radar image.
  3. Ask minicpm-v4.6 to describe it using the improved water-aware prompt.
  4. Score the result: did the AI correctly identify precipitation presence/absence?
     Did it hallucinate a warning when NWS has none?

Produces both individual reports (weather_<zip>_<stamp>.txt) and a summary
(experiment_summary_<stamp>.txt) with a scored accuracy table.

Usage:
    python run_minicpm_experiment.py
    python run_minicpm_experiment.py --model minicpm-v4.6  # override model
    python run_minicpm_experiment.py --zoom 100            # crop to 100km radius
"""

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

NWS_HEADERS = {
    "Accept": "application/geo+json",
    "User-Agent": "QuickRadar/1.0 (weather-app research; contact: local)",
}

# ---------------------------------------------------------------------------
# 20 zipcodes — mix of geographic diversity and June weather likelihood.
# Southeast, Plains, Gulf Coast, and Great Lakes skew toward active convection
# in June; Desert SW and Rocky Mtn give clear-sky baselines.
# ---------------------------------------------------------------------------
LOCATIONS = [
    # --- Midwest (radar well-sampled) ---
    ("53703", "Madison WI",        "KMKX — 69km away, Great Lakes proximity"),
    ("60601", "Chicago IL",        "KLOT — Lake Michigan edge, dense coverage"),
    ("44101", "Cleveland OH",      "KCLE — Lake Erie, lake-effect region"),
    # --- Southeast / Gulf (high convective June activity) ---
    ("30301", "Atlanta GA",        "KFFC — inland SE, afternoon thunderstorms"),
    ("33101", "Miami FL",          "KAMX — South Florida, daily convection"),
    ("28201", "Charlotte NC",      "KGSP — Appalachian foothills"),
    ("39401", "Hattiesburg MS",    "KLIX — Gulf Coast corridor"),
    ("70112", "New Orleans LA",    "KLIX — Gulf Coast, maritime moisture"),
    ("32201", "Jacksonville FL",   "KJAX — NE Florida, sea-breeze convection"),
    # --- Plains / Tornado Alley ---
    ("73072", "Norman OK",         "KTLX — tornado alley, SPC prime area"),
    ("67202", "Wichita KS",        "KICT — central plains convection"),
    ("79401", "Lubbock TX",        "KLBB — west Texas, haboobs and convection"),
    ("77002", "Houston TX",        "KHGX — Gulf Coast TX, sea-breeze"),
    # --- Northeast ---
    ("10001", "New York NY",       "KOKX — I-95 corridor, NE weather systems"),
    ("02101", "Boston MA",         "KBOX — coastal NE, nor'easter track"),
    # --- Mountain West / Pacific ---
    ("80202", "Denver CO",         "KFTG — Front Range, afternoon storms June"),
    ("98101", "Seattle WA",        "KATX — PNW, marine layer"),
    ("94102", "San Francisco CA",  "KMUX — marine stratus, usually clear radar"),
    # --- Desert Southwest (high clear-sky baseline) ---
    ("85001", "Phoenix AZ",        "KIWA — desert, monsoon not yet active"),
    ("89101", "Las Vegas NV",      "KESX — desert, typically clear"),
]

DEFAULT_MODEL = "minicpm-v4.6"


# ---------------------------------------------------------------------------
# NWS: fetch current conditions and active alerts for a point
# ---------------------------------------------------------------------------
def get_ground_truth(lat: float, lon: float) -> dict:
    """Return NWS ground truth: has_precip, precip_mm, alerts, conditions text."""
    result = {
        "has_precip": False,
        "precip_mm": None,
        "precip_description": "",
        "conditions": "",
        "alerts": [],
        "station_id": "",
        "obs_time": "",
        "error": None,
    }
    try:
        # Points → observation stations
        pr = requests.get(
            f"https://api.weather.gov/points/{lat:.4f},{lon:.4f}",
            headers=NWS_HEADERS, timeout=20
        )
        pr.raise_for_status()
        props = pr.json().get("properties", {})
        stations_url = props.get("observationStations", "")

        if stations_url:
            sr = requests.get(stations_url, headers=NWS_HEADERS, timeout=20)
            sr.raise_for_status()
            feats = sr.json().get("features", [])
            if feats:
                sid = feats[0]["properties"].get("stationIdentifier", "")
                result["station_id"] = sid
                obs_r = requests.get(
                    f"https://api.weather.gov/stations/{sid}/observations/latest",
                    headers=NWS_HEADERS, timeout=20
                )
                obs_r.raise_for_status()
                obs = obs_r.json().get("properties", {})
                result["obs_time"] = obs.get("timestamp", "")
                result["conditions"] = obs.get("textDescription", "")

                def _val(f):
                    v = obs.get(f)
                    if isinstance(v, dict):
                        return v.get("value")
                    return v

                p1h = _val("precipitationLastHour")
                p3h = _val("precipitationLast3Hours")
                if p1h and p1h > 0:
                    result["has_precip"] = True
                    result["precip_mm"] = p1h
                    result["precip_description"] = f"{p1h:.1f} mm last hour"
                elif p3h and p3h > 0:
                    result["has_precip"] = True
                    result["precip_mm"] = p3h
                    result["precip_description"] = f"{p3h:.1f} mm last 3hr"

                # presentWeather codes as backup
                pw = obs.get("presentWeather") or []
                for w in pw:
                    wtype = w.get("weather", "")
                    if wtype and wtype.lower() not in ("", "none"):
                        result["has_precip"] = True
                        if not result["precip_description"]:
                            result["precip_description"] = wtype

        # Active alerts
        ar = requests.get(
            f"https://api.weather.gov/alerts/active?point={lat:.4f},{lon:.4f}",
            headers=NWS_HEADERS, timeout=20
        )
        ar.raise_for_status()
        for feat in ar.json().get("features", []):
            ap = feat.get("properties", {})
            result["alerts"].append({
                "event": ap.get("event", ""),
                "headline": ap.get("headline", ""),
            })

    except Exception as e:
        result["error"] = str(e)

    return result


# ---------------------------------------------------------------------------
# Run quickradar.py for one zipcode and return the report path
# ---------------------------------------------------------------------------
def run_quickradar(zipcode: str, model: str, zoom: float | None) -> tuple[bool, Path | None, str]:
    """Invoke quickradar.py as a subprocess. Returns (success, report_path, stdout)."""
    cmd = [sys.executable, "quickradar.py", zipcode, "--model", model]
    if zoom is not None:
        cmd += ["--zoom", str(zoom)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    stdout = result.stdout + result.stderr

    if result.returncode != 0:
        return False, None, stdout

    # Find the report file from stdout ("Report written to: <path>")
    for line in stdout.splitlines():
        if "Report written to:" in line:
            p = Path(line.split("Report written to:")[-1].strip())
            if p.exists():
                return True, p, stdout

    return True, None, stdout


# ---------------------------------------------------------------------------
# Parse key fields from a quickradar report
# ---------------------------------------------------------------------------
def parse_report(report_path: Path) -> dict:
    """Extract the AI description and model from a quickradar text report."""
    if report_path is None or not report_path.exists():
        return {"ai_description": "", "model": ""}
    text = report_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    ai_desc_lines = []
    in_desc = False
    for line in lines:
        if "RADAR IMAGE DESCRIPTION" in line:
            in_desc = True
            continue
        if in_desc and line.startswith("---"):
            # Next dashes = end of section
            if ai_desc_lines:
                break
            continue
        if in_desc:
            ai_desc_lines.append(line)

    model = ""
    for line in lines:
        if line.startswith("Ollama model:"):
            model = line.split(":", 1)[-1].strip()
            break

    return {
        "ai_description": "\n".join(ai_desc_lines).strip(),
        "model": model,
    }


# ---------------------------------------------------------------------------
# Score one result: precip and warning accuracy
# ---------------------------------------------------------------------------
def score(ground_truth: dict, ai_description: str) -> dict:
    """
    Heuristic scoring — looks for keywords in the AI description.

    Returns:
      ai_claims_precip  — bool: AI said precipitation is present
      ai_claims_warning — bool: AI said an active warning polygon is on the map
      precip_correct    — True/False/None (None if we can't determine ground truth)
      warning_correct   — True/False/None
    """
    desc_lower = ai_description.lower()

    # Precipitation: look for positive indicators
    precip_positive = any(kw in desc_lower for kw in [
        "precipitation", "rain", "shower", "storm", "drizzle", "snow", "hail",
        "green", "yellow", "orange", "red", "light rain", "moderate", "heavy",
    ])
    # Strong negatives: "no precipitation", "mostly clear", "no rain", "clear map"
    precip_negative = any(kw in desc_lower for kw in [
        "no precipitation", "no rain", "mostly clear", "map is clear",
        "map area is clear", "no precip", "clear map", "clear radar",
        "no detected precipitation", "no echo", "appears clear",
        "map appears clear", "no green", "no yellow", "no orange", "no red",
        "no active precipitation",
    ])
    # If negative keywords dominate, treat as "AI says no precip"
    ai_claims_precip = precip_positive and not precip_negative

    # Warning: did AI say a warning polygon is actually on the map?
    warning_positive = any(kw in desc_lower for kw in [
        "warning polygon", "active warning", "warning is active",
        "active tornado", "tornado warning active",
        "severe thunderstorm warning active",
        "warning drawn on the map",
        "polygon drawn",
        "warning on the map",
    ])
    # Explicit "no warning" phrases
    warning_negative = any(kw in desc_lower for kw in [
        "no active warning", "no warning polygon", "no warning",
        "no tornado", "legend only", "legend key", "no polygon",
        "not active", "reference only", "no colored polygon",
    ])
    ai_claims_warning = warning_positive and not warning_negative

    # Ground truth
    gt_has_precip = ground_truth.get("has_precip")
    gt_has_alerts = len(ground_truth.get("alerts", [])) > 0

    precip_correct = None
    if gt_has_precip is not None:
        precip_correct = (ai_claims_precip == gt_has_precip)

    warning_correct = None
    # We can always check warning accuracy (ground truth from NWS alerts)
    warning_correct = (ai_claims_warning == gt_has_alerts)

    return {
        "ai_claims_precip": ai_claims_precip,
        "ai_claims_warning": ai_claims_warning,
        "precip_correct": precip_correct,
        "warning_correct": warning_correct,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description="Multi-location minicpm-v4.6 radar accuracy experiment")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--zoom", type=float, default=None)
    args = parser.parse_args()

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    summary_path = Path(f"experiment_summary_{stamp}.txt")

    print(f"MINICPM-V4.6 RADAR ACCURACY EXPERIMENT")
    print(f"Model: {args.model}  Zoom: {args.zoom or 'none (full radar)'}")
    print(f"Locations: {len(LOCATIONS)}")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    rows = []

    for idx, (zipcode, city, note) in enumerate(LOCATIONS, 1):
        print(f"\n[{idx}/{len(LOCATIONS)}] {city} ({zipcode}) — {note}")

        # Step 1: geocode to get lat/lon for ground truth
        try:
            geo_r = requests.get(f"https://api.zippopotam.us/us/{zipcode}", timeout=15)
            geo_r.raise_for_status()
            geo = geo_r.json()
            lat = float(geo["places"][0]["latitude"])
            lon = float(geo["places"][0]["longitude"])
        except Exception as e:
            print(f"  geocode failed: {e} — skipping")
            rows.append({"zipcode": zipcode, "city": city, "error": str(e)})
            continue

        # Step 2: pre-check ground truth
        print(f"  checking NWS ground truth...")
        gt = get_ground_truth(lat, lon)
        has_precip_str = "YES" if gt["has_precip"] else "no"
        alerts_str = f"{len(gt['alerts'])} alert(s)" if gt["alerts"] else "no alerts"
        print(f"  ground truth: precip={has_precip_str}  alerts={alerts_str}  cond='{gt['conditions']}'")
        if gt.get("error"):
            print(f"  (NWS error: {gt['error']})")

        # Step 3: run quickradar
        print(f"  running minicpm-v4.6...")
        ok, report_path, stdout = run_quickradar(zipcode, args.model, args.zoom)
        if not ok:
            print(f"  quickradar FAILED")
            rows.append({"zipcode": zipcode, "city": city, "error": "quickradar failed", "ground_truth": gt})
            time.sleep(2)
            continue

        # Step 4: parse AI output and score
        parsed = parse_report(report_path)
        sc = score(gt, parsed["ai_description"])

        precip_verdict = "✓" if sc["precip_correct"] else ("✗" if sc["precip_correct"] is False else "?")
        warn_verdict = "✓" if sc["warning_correct"] else "✗"
        print(f"  AI claims precip: {sc['ai_claims_precip']}  (truth: {gt['has_precip']})  → {precip_verdict}")
        print(f"  AI claims warning: {sc['ai_claims_warning']}  (truth: {len(gt['alerts'])>0})  → {warn_verdict}")
        if report_path:
            print(f"  report: {report_path.name}")

        rows.append({
            "zipcode": zipcode,
            "city": city,
            "lat": lat,
            "lon": lon,
            "ground_truth": gt,
            "ai_description": parsed["ai_description"],
            "score": sc,
            "report_path": str(report_path) if report_path else "",
        })

        time.sleep(3)  # be polite to NWS APIs

    # ---------------------------------------------------------------------------
    # Summary report
    # ---------------------------------------------------------------------------
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        "=" * 70,
        "MINICPM-V4.6 RADAR ACCURACY EXPERIMENT — SUMMARY",
        "=" * 70,
        f"Model:   {args.model}",
        f"Zoom:    {args.zoom or 'none (full radar range)'}",
        f"Ran at:  {now_str}",
        f"Locations tested: {len(rows)}",
        "",
        "-" * 70,
        "ACCURACY TABLE",
        "-" * 70,
        "",
        f"{'Location':<22} {'GT Precip':>10} {'AI Precip':>10} {'P?':>4}  {'GT Alert':>9} {'AI Alert':>9} {'W?':>4}",
        "-" * 70,
    ]

    # Counts
    precip_correct_n = 0
    precip_total_n = 0
    warning_correct_n = 0
    warning_total_n = 0
    has_precip_samples = []
    clear_samples = []

    for row in rows:
        if "score" not in row:
            lines.append(f"  {row['city']:<20} ERROR: {row.get('error','')}")
            continue
        gt = row["ground_truth"]
        sc = row["score"]

        gt_p = "yes" if gt["has_precip"] else "no"
        ai_p = "yes" if sc["ai_claims_precip"] else "no"
        p_mark = "✓" if sc["precip_correct"] else ("✗" if sc["precip_correct"] is False else "?")

        gt_w = "yes" if gt["alerts"] else "no"
        ai_w = "yes" if sc["ai_claims_warning"] else "no"
        w_mark = "✓" if sc["warning_correct"] else "✗"

        lines.append(
            f"  {row['city']:<20} {gt_p:>10} {ai_p:>10} {p_mark:>4}  "
            f"{gt_w:>9} {ai_w:>9} {w_mark:>4}"
        )

        if sc["precip_correct"] is not None:
            precip_total_n += 1
            if sc["precip_correct"]:
                precip_correct_n += 1
        warning_total_n += 1
        if sc["warning_correct"]:
            warning_correct_n += 1

        if gt["has_precip"]:
            has_precip_samples.append(row)
        else:
            clear_samples.append(row)

    lines += [
        "",
        "-" * 70,
        "ACCURACY TOTALS",
        "-" * 70,
        f"  Precipitation detection: {precip_correct_n}/{precip_total_n}  "
        f"({100*precip_correct_n//precip_total_n if precip_total_n else 0}%)",
        f"  Warning accuracy:        {warning_correct_n}/{warning_total_n}  "
        f"({100*warning_correct_n//warning_total_n if warning_total_n else 0}%)",
        f"",
        f"  Samples WITH precipitation: {len(has_precip_samples)}",
        f"  Samples WITHOUT precipitation: {len(clear_samples)}",
        "",
    ]

    # Detail: false positives (AI sees precip, NWS says clear)
    false_positives = [r for r in rows if "score" in r
                       and not r["ground_truth"]["has_precip"]
                       and r["score"]["ai_claims_precip"]]
    false_negatives = [r for r in rows if "score" in r
                       and r["ground_truth"]["has_precip"]
                       and not r["score"]["ai_claims_precip"]]
    warning_fp = [r for r in rows if "score" in r
                  and not r["ground_truth"]["alerts"]
                  and r["score"]["ai_claims_warning"]]

    if false_positives:
        lines += ["-" * 70, "FALSE POSITIVES — AI saw precipitation, NWS says clear:", "-" * 70]
        for r in false_positives:
            lines.append(f"  {r['city']} ({r['zipcode']}): {r['ground_truth']['conditions']}")
            desc = r["ai_description"][:300].replace("\n", " ")
            lines.append(f"    AI: {desc}...")
            lines.append("")

    if false_negatives:
        lines += ["-" * 70, "FALSE NEGATIVES — AI missed precipitation NWS confirmed:", "-" * 70]
        for r in false_negatives:
            lines.append(f"  {r['city']} ({r['zipcode']}): {r['ground_truth']['precip_description']}")
            desc = r["ai_description"][:300].replace("\n", " ")
            lines.append(f"    AI: {desc}...")
            lines.append("")

    if warning_fp:
        lines += ["-" * 70, "WARNING FALSE POSITIVES — AI hallucinated alert, NWS has none:", "-" * 70]
        for r in warning_fp:
            lines.append(f"  {r['city']} ({r['zipcode']})")
            desc = r["ai_description"][:300].replace("\n", " ")
            lines.append(f"    AI: {desc}...")
            lines.append("")

    # Per-sample AI descriptions
    lines += ["=" * 70, "FULL AI DESCRIPTIONS PER LOCATION", "=" * 70, ""]
    for row in rows:
        gt = row.get("ground_truth", {})
        lines.append(f"--- {row['city']} ({row['zipcode']}) ---")
        lines.append(f"NWS: {gt.get('conditions', 'N/A')}  |  "
                     f"precip: {gt.get('precip_description') or 'none'}  |  "
                     f"alerts: {len(gt.get('alerts', []))}")
        lines.append("")
        lines.append(row.get("ai_description", "[no description]"))
        lines.append("")

    summary_text = "\n".join(lines)
    summary_path.write_text(summary_text, encoding="utf-8")
    print(f"\n\nSummary written to: {summary_path.resolve()}")
    print(f"Precipitation accuracy: {precip_correct_n}/{precip_total_n}")
    print(f"Warning accuracy: {warning_correct_n}/{warning_total_n}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
