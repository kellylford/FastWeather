"""Shared formatting for weather alerts (list rows and full detail)."""

from datetime import datetime


def fmt_time(iso):
    if not iso:
        return ""
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00")).strftime("%a %b %d %I:%M %p")
    except Exception:
        return iso


def summary_row(alert):
    """One-line list label: '[Severity] Event - headline'."""
    text = f"[{alert.severity}] {alert.event}"
    if alert.headline and alert.headline != alert.event:
        text += f" - {alert.headline}"
    return text


def detail_lines(alert):
    """Full accessible detail for a single alert, as a list of lines."""
    lines = [f"{alert.severity.upper()} - {alert.event}"]
    if alert.headline and alert.headline != alert.event:
        lines.append(alert.headline)
    lines.append("")
    if alert.area:
        lines.append(f"Affected Areas: {alert.area}")
    when = " - ".join(x for x in [fmt_time(alert.onset), fmt_time(alert.ends)] if x)
    if when:
        lines.append(f"Valid: {when}")
    lines.append("")
    if alert.description:
        lines.append("Details:")
        for seg in alert.description.split("\n"):
            seg = seg.strip()
            if seg:
                lines.append(f"  {seg}")
        lines.append("")
    if alert.instruction:
        lines.append("Safety Instructions:")
        for seg in alert.instruction.split("\n"):
            seg = seg.strip()
            if seg:
                lines.append(f"  {seg}")
        lines.append("")
    lines.append(f"Source: {alert.source}")
    if alert.details_url:
        lines.append(f"More info: {alert.details_url}")
    return lines
