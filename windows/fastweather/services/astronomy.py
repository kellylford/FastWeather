"""Local moon-phase astronomy (no network).

Computes the lunar phase, illuminated fraction, moon age, phase name, and the
dates of the next new and full moons from a synodic-month reference epoch.
Moonrise/moonset require a full ephemeris and are intentionally omitted rather
than approximated inaccurately.
"""

import math
from datetime import date, timedelta

SYNODIC_MONTH = 29.53058867
# Reference new moon: 2000-01-06 18:14 UTC as Julian Day.
_REF_NEW_MOON_JD = 2451550.1

PHASE_NAMES = [
    "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
    "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent",
]


def _julian_day(d):
    """Julian Day number for a date (at 00:00), Fliegel-Van Flandern."""
    a = (14 - d.month) // 12
    y = d.year + 4800 - a
    m = d.month + 12 * a - 3
    jdn = (d.day + (153 * m + 2) // 5 + 365 * y + y // 4 - y // 100
           + y // 400 - 32045)
    return jdn - 0.5  # midnight


def moon_age_days(d=None):
    d = d or date.today()
    age = (_julian_day(d) - _REF_NEW_MOON_JD) % SYNODIC_MONTH
    return age


def illumination(d=None):
    """Illuminated fraction 0..1."""
    age = moon_age_days(d)
    return (1 - math.cos(2 * math.pi * age / SYNODIC_MONTH)) / 2


def phase_name(d=None):
    age = moon_age_days(d)
    idx = int((age / SYNODIC_MONTH) * 8 + 0.5) % 8
    return PHASE_NAMES[idx]


def _days_until(target_fraction, d):
    """Days from d until the moon reaches a given age-fraction of the cycle."""
    age = moon_age_days(d)
    target_age = target_fraction * SYNODIC_MONTH
    delta = (target_age - age) % SYNODIC_MONTH
    return delta


def next_new_moon(d=None):
    d = d or date.today()
    return d + timedelta(days=round(_days_until(0.0, d)))


def next_full_moon(d=None):
    d = d or date.today()
    return d + timedelta(days=round(_days_until(0.5, d)))


def summary(d=None):
    """Dict of moon facts for display."""
    d = d or date.today()
    return {
        "phase": phase_name(d),
        "illumination_pct": round(illumination(d) * 100),
        "age_days": round(moon_age_days(d), 1),
        "next_new_moon": next_new_moon(d).isoformat(),
        "next_full_moon": next_full_moon(d).isoformat(),
    }
