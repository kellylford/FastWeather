import unittest

from fastweather import geo
from fastweather.services import directional_service


class GeoTests(unittest.TestCase):
    def test_haversine_known(self):
        # 1 degree of longitude at 43N is ~81 km
        d = geo.haversine_km(43.0, -89.0, 43.0, -88.0)
        self.assertTrue(80 < d < 82, d)

    def test_destination_roundtrip(self):
        lat, lon = geo.destination_point(43.0, -89.0, 90, 100)
        back = geo.haversine_km(43.0, -89.0, lat, lon)
        self.assertAlmostEqual(back, 100, delta=0.5)
        self.assertAlmostEqual(geo.bearing_deg(43.0, -89.0, lat, lon), 90, delta=1)

    def test_angular_diff(self):
        self.assertEqual(geo.angular_diff(10, 350), 20)
        self.assertEqual(geo.angular_diff(0, 180), 180)

    def test_cross_track_small_on_line(self):
        # a point due east on the eastward line has ~0 cross-track distance
        lat, lon = geo.destination_point(43.0, -89.0, 90, 50)
        ct = geo.cross_track_km(43.0, -89.0, 90, lat, lon)
        self.assertLess(ct, 1.0)


class DirectionalTests(unittest.TestCase):
    def setUp(self):
        self._orig = directional_service.weather_service.fetch_weather
        directional_service.weather_service.fetch_weather = (
            lambda a, b, c: {"current": {"temperature_2m": 20, "weather_code": 1}}
        )

    def tearDown(self):
        directional_service.weather_service.fetch_weather = self._orig

    def test_arc_filters_direction(self):
        center = (43.0, -89.0)
        cities = [
            {"display": "East", "lat": geo.destination_point(*center, 90, 100)[0],
             "lon": geo.destination_point(*center, 90, 100)[1]},
            {"display": "West", "lat": geo.destination_point(*center, 270, 100)[0],
             "lon": geo.destination_point(*center, 270, 100)[1]},
        ]
        east = directional_service.find_cities(
            center[0], center[1], 90, cities, mode="arc", width="Standard",
            max_distance_km=400)
        names = [c["display"] for c in east]
        self.assertIn("East", names)
        self.assertNotIn("West", names)


if __name__ == "__main__":
    unittest.main()
