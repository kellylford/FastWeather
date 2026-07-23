import unittest

from fastweather.services import geocoding_service as g


def _result(name, addr, cls="place", type_="city", importance=0.5, lat=1.0, lon=2.0):
    return {
        "namedetails": {"name": name}, "name": name, "address": addr,
        "class": cls, "type": type_, "addresstype": type_,
        "importance": importance, "lat": str(lat), "lon": str(lon),
    }


class BuildMatchTests(unittest.TestCase):
    def test_specific_place_leads_with_name(self):
        r = _result("Stanford University",
                    {"city": "Stanford", "state": "California", "country": "United States"},
                    cls="amenity", type_="university")
        m = g.build_match(r, specific=True)
        self.assertEqual(m["display"],
                         "Stanford University - Stanford, California, United States")

    def test_locality_only_when_specific_off(self):
        r = _result("Stanford University",
                    {"city": "Stanford", "state": "California", "country": "United States"},
                    cls="amenity", type_="university")
        m = g.build_match(r, specific=False)
        self.assertEqual(m["display"], "Stanford, California, United States")

    def test_plain_city_unchanged(self):
        r = _result("Chicago",
                    {"city": "Chicago", "state": "Illinois", "country": "United States"})
        m = g.build_match(r, specific=True)
        self.assertEqual(m["display"], "Chicago, Illinois, United States")

    def test_name_equals_locality_uses_locality_label(self):
        # Madison the city: name == city -> not treated as a distinct place.
        r = _result("Madison",
                    {"city": "Madison", "state": "Wisconsin", "country": "United States"})
        self.assertEqual(g.build_match(r, specific=True)["display"],
                         "Madison, Wisconsin, United States")


class GeocodeSortTests(unittest.TestCase):
    def setUp(self):
        self._orig = g.http.get_json

    def tearDown(self):
        g.http.get_json = self._orig

    def test_sorts_by_importance(self):
        g.http.get_json = lambda *a, **k: [
            _result("Obscure Road", {"city": "Nowhere", "country": "Chile"},
                    cls="highway", type_="residential", importance=0.05),
            _result("Big University", {"city": "Madison", "state": "Wisconsin",
                                       "country": "United States"},
                    cls="amenity", type_="university", importance=0.65),
        ]
        matches = g.geocode("query", specific=True)
        self.assertEqual(matches[0]["name"], "Big University")  # importance wins


if __name__ == "__main__":
    unittest.main()
