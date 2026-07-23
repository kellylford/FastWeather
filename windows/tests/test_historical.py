import unittest

from fastweather.models.historical import HistoricalDay
from fastweather.models.settings import AppSettings
from fastweather.services import historical_service
from fastweather.ui.dialogs.historical_dialog import format_day_line
from fastweather.ui.formatters import Formatter


class HistoricalTests(unittest.TestCase):
    def test_day_from(self):
        daily = {
            "time": ["2000-01-01", "2000-01-02"],
            "temperature_2m_max": [1.0, 2.0],
            "temperature_2m_min": [-3.0, -2.0],
            "precipitation_sum": [0.0, 5.0],
            "snowfall_sum": [0.0, 1.0],
            "windspeed_10m_max": [10.0, 20.0],
            "weathercode": [3, 71],
        }
        day = historical_service._day_from(daily, 1)
        self.assertEqual(day.date, "2000-01-02")
        self.assertEqual(day.temp_max, 2.0)
        self.assertEqual(day.weather_code, 71)

    def test_format_day_line(self):
        fmt = Formatter(AppSettings())
        day = HistoricalDay(date="2000-01-02", temp_max=2.0, temp_min=-2.0,
                            precip_sum=5.0, weather_code=71)
        line = format_day_line(day, fmt)
        self.assertIn("2000-01-02", line)
        self.assertIn("High 36°F", line)   # 2C -> 36F
        self.assertIn("Slight snow fall", line)

    def test_format_day_line_error(self):
        fmt = Formatter(AppSettings())
        line = format_day_line(HistoricalDay(date="2000-01-02", error="No data"), fmt)
        self.assertIn("unavailable", line)

    def test_multi_year_dates(self):
        captured = []
        orig = historical_service.fetch_single_day
        historical_service.fetch_single_day = (
            lambda lat, lon, iso: captured.append(iso) or HistoricalDay(date=iso))
        try:
            days = historical_service.fetch_multi_year(1.0, 2.0, 7, 4, 3)
        finally:
            historical_service.fetch_single_day = orig
        self.assertEqual(len(days), 3)
        # all requested dates end in -07-04
        self.assertTrue(all(iso.endswith("-07-04") for iso in captured))


if __name__ == "__main__":
    unittest.main()
