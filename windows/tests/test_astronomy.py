import unittest
from datetime import date

from fastweather.services import astronomy
from fastweather.models.settings import AppSettings
from fastweather.ui.formatters import Formatter
from fastweather.ui.full_weather_view import build_today_outlook


class AstronomyTests(unittest.TestCase):
    def test_illumination_range(self):
        for d in (date(2026, 1, 1), date(2026, 7, 22), date(2026, 12, 31)):
            self.assertTrue(0.0 <= astronomy.illumination(d) <= 1.0)

    def test_phase_name_valid(self):
        self.assertIn(astronomy.phase_name(date(2026, 7, 22)), astronomy.PHASE_NAMES)

    def test_summary_keys(self):
        s = astronomy.summary(date(2026, 7, 22))
        for k in ("phase", "illumination_pct", "age_days", "next_new_moon", "next_full_moon"):
            self.assertIn(k, s)

    def test_new_moon_near_illumination_zero(self):
        nm = date.fromisoformat(astronomy.next_new_moon(date(2026, 7, 22)).isoformat())
        self.assertLess(astronomy.illumination(nm), 0.06)


class TodayOutlookTests(unittest.TestCase):
    def test_precip_window(self):
        fmt = Formatter(AppSettings())
        data = {
            "current": {"time": "2026-07-22T12:00"},
            "hourly": {
                "time": ["2026-07-22T12:00", "2026-07-22T13:00", "2026-07-22T14:00",
                         "2026-07-22T15:00"],
                "precipitation_probability": [10, 60, 80, 20],
            },
            "daily": {"uv_index_max": [8], "windspeed_10m_max": [10]},
        }
        out = build_today_outlook(data, AppSettings(), fmt)
        self.assertTrue(any("1 PM-2 PM" in ln for ln in out), out)
        self.assertTrue(any("High UV" in ln for ln in out))


if __name__ == "__main__":
    unittest.main()
