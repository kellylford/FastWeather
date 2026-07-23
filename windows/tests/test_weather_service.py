import unittest

from fastweather.services import http, weather_service


class WeatherServiceParamTests(unittest.TestCase):
    def setUp(self):
        self.captured = {}

        def fake_get_json(url, params=None, headers=None, timeout=None):
            self.captured["url"] = url
            self.captured["params"] = params
            return {"ok": True}

        self._orig = http.get_json
        weather_service.http.get_json = fake_get_json

    def tearDown(self):
        weather_service.http.get_json = self._orig

    def test_basic_request(self):
        weather_service.fetch_weather(1.0, 2.0, "basic")
        p = self.captured["params"]
        self.assertEqual(p["latitude"], 1.0)
        self.assertEqual(p["timezone"], "auto")
        self.assertEqual(p["forecast_days"], 1)
        self.assertEqual(p["hourly"], "cloudcover")
        self.assertIn("temperature_2m", p["current"])

    def test_full_request(self):
        weather_service.fetch_weather(1.0, 2.0, "full", forecast_days=16)
        p = self.captured["params"]
        self.assertEqual(p["forecast_days"], 16)
        self.assertIn("uv_index", p["hourly"])
        self.assertIn("dewpoint_2m", p["hourly"])
        self.assertIn("temperature_2m_max", p["daily"])
        self.assertIn("sunrise", p["daily"])


if __name__ == "__main__":
    unittest.main()
