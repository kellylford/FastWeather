import unittest

from fastweather.services import location_service


class LocationServiceTests(unittest.TestCase):
    def setUp(self):
        self._orig_http = location_service.http.get_json
        self._orig_win = location_service._try_windows_location

    def tearDown(self):
        location_service.http.get_json = self._orig_http
        location_service._try_windows_location = self._orig_win

    def test_ip_fallback(self):
        location_service._try_windows_location = lambda: None
        location_service.http.get_json = lambda *a, **k: {
            "latitude": 43.07, "longitude": -89.4,
            "city": "Madison", "region": "Wisconsin", "country_name": "United States",
        }
        loc = location_service.get_location()
        self.assertEqual(loc["source"], "IP")
        self.assertEqual(loc["name"], "Madison, Wisconsin, United States")
        self.assertAlmostEqual(loc["lat"], 43.07)

    def test_ip_missing_coords_raises(self):
        location_service._try_windows_location = lambda: None
        location_service.http.get_json = lambda *a, **k: {"city": "Nowhere"}
        with self.assertRaises(Exception):
            location_service.get_location()

    def test_windows_precise_used_first(self):
        location_service._try_windows_location = lambda: (10.0, 20.0)
        from fastweather.services import geocoding_service
        orig = geocoding_service.reverse_geocode
        geocoding_service.reverse_geocode = lambda lat, lon: "Testville"
        try:
            loc = location_service.get_location()
        finally:
            geocoding_service.reverse_geocode = orig
        self.assertEqual(loc["source"], "GPS")
        self.assertEqual(loc["name"], "Testville")

    def test_ip_disabled_raises(self):
        location_service._try_windows_location = lambda: None
        with self.assertRaises(Exception):
            location_service.get_location(allow_ip=False)


if __name__ == "__main__":
    unittest.main()
