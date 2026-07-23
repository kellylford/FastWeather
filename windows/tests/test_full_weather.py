import unittest

from fastweather.models.settings import AppSettings, default_config
from fastweather.ui.formatters import Formatter
from fastweather.ui.full_weather_view import build_full_weather_lines

# Canned payload: day 2 has a None max temp and hour 2 a None temp (real API quirk).
DATA = {
    "current": {
        "time": "2026-07-22T01:00", "temperature_2m": 20.0,
        "apparent_temperature": 18.0, "relative_humidity_2m": 60,
        "wind_speed_10m": 10.0, "wind_direction_10m": 90, "cloud_cover": 5,
    },
    "hourly": {
        "time": ["2026-07-22T01:00", "2026-07-22T02:00"],
        "temperature_2m": [20.0, None],
        "precipitation": [0, 0],
        "relative_humidity_2m": [60, 61],
    },
    "daily": {
        "time": ["2026-07-22", "2026-07-23"],
        "temperature_2m_max": [25.0, None],
        "temperature_2m_min": [15.0, 14.0],
        "sunrise": ["2026-07-22T05:30", "2026-07-23T05:31"],
        "sunset": ["2026-07-22T20:30", "2026-07-23T20:29"],
        "precipitation_sum": [0, 0],
    },
}


class FullWeatherTests(unittest.TestCase):
    def _build(self, cfg=None):
        s = AppSettings(cfg or default_config())
        return build_full_weather_lines("Testville", DATA, s, Formatter(s))

    def test_current_section(self):
        lines = self._build()
        self.assertIn("Report for Testville", lines)
        self.assertIn("CURRENT", lines)
        self.assertIn("Temp: 68.0°F", lines)          # 20C -> 68F
        self.assertIn("Feels Like: 64.4°F", lines)     # 18C -> 64.4F
        self.assertIn("Humidity: 60%", lines)

    def test_none_values_are_skipped_not_crashing(self):
        # day 2 max is None: its line must have Low but not High, no exception.
        lines = self._build()
        day2 = [ln for ln in lines if ln.startswith("Thu Jul 23")]
        self.assertEqual(len(day2), 1)
        self.assertIn("Low 57°F", day2[0])   # 14C -> 57F
        self.assertNotIn("High", day2[0])

    def test_hourly_none_temp_skipped(self):
        lines = self._build()
        # second hour (02:00 AM) had None temp -> no temp token, still a line
        hour2 = [ln for ln in lines if ln.startswith("02:00 AM")]
        self.assertEqual(len(hour2), 1)
        self.assertNotIn("°F", hour2[0].replace("02:00 AM:", ""))

    def test_footer(self):
        self.assertEqual(self._build()[-1], "Data by Open-Meteo.com (CC BY 4.0)")


if __name__ == "__main__":
    unittest.main()
