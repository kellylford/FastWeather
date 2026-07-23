import unittest

from fastweather.models.radar import intensity_label
from fastweather.services import radar_service


class IntensityTests(unittest.TestCase):
    def test_bands(self):
        self.assertEqual(intensity_label(0), "None")
        self.assertEqual(intensity_label(None), "None")
        self.assertEqual(intensity_label(0.3), "Light")     # 1.2 mm/h
        self.assertEqual(intensity_label(1.0), "Moderate")  # 4.0 mm/h
        self.assertEqual(intensity_label(3.0), "Heavy")     # 12 mm/h


class NowcastTests(unittest.TestCase):
    def setUp(self):
        self._orig = radar_service.http.get_json

    def tearDown(self):
        radar_service.http.get_json = self._orig

    def _mock(self, precip):
        times = [f"2026-07-22T12:{m:02d}" for m in (0, 15, 30, 45)] + ["2026-07-22T13:00"]
        radar_service.http.get_json = lambda *a, **k: {
            "current": {"time": "2026-07-22T12:00"},
            "minutely_15": {"time": times, "precipitation": precip},
        }

    def test_starts_later(self):
        self._mock([0.0, 0.0, 0.5, 1.0, 0.0])
        nc = radar_service.fetch_nowcast(1, 2)
        self.assertEqual(nc.starts_in_minutes, 30)
        self.assertIn("30 min", nc.status)

    def test_precip_now(self):
        self._mock([1.0, 1.0, 0.0, 0.0, 0.0])
        nc = radar_service.fetch_nowcast(1, 2)
        self.assertIn("now", nc.status.lower())

    def test_none(self):
        self._mock([0.0, 0.0, 0.0, 0.0, 0.0])
        nc = radar_service.fetch_nowcast(1, 2)
        self.assertIn("No precipitation", nc.status)


if __name__ == "__main__":
    unittest.main()
