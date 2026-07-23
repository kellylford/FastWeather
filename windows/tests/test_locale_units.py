import unittest

from fastweather.locale_units import default_units_for_country


class LocaleUnitsTests(unittest.TestCase):
    def test_us(self):
        u = default_units_for_country("US")
        self.assertEqual(u, {"temperature": "F", "wind_speed": "mph",
                             "precipitation": "in", "distance": "mi",
                             "pressure": "inHg"})

    def test_uk_metric_but_mph_and_miles(self):
        u = default_units_for_country("GB")
        self.assertEqual(u["temperature"], "C")
        self.assertEqual(u["wind_speed"], "mph")   # UK reports wind in mph
        self.assertEqual(u["distance"], "mi")       # and distance in miles
        self.assertEqual(u["precipitation"], "mm")
        self.assertEqual(u["pressure"], "hPa")

    def test_meters_per_second_countries(self):
        for code in ("NO", "SE", "FI", "RU", "CN", "JP", "NL"):
            self.assertEqual(default_units_for_country(code)["wind_speed"], "m/s", code)

    def test_kmh_default_metric(self):
        for code in ("FR", "ES", "IT", "AU", "CA", "BR"):
            u = default_units_for_country(code)
            self.assertEqual(u["wind_speed"], "km/h", code)
            self.assertEqual(u["temperature"], "C", code)

    def test_russia_pressure_mmhg(self):
        self.assertEqual(default_units_for_country("RU")["pressure"], "mmHg")

    def test_unknown_country_is_metric_kmh(self):
        u = default_units_for_country("ZZ")
        self.assertEqual(u["wind_speed"], "km/h")
        self.assertEqual(u["temperature"], "C")
        self.assertEqual(u["pressure"], "hPa")


if __name__ == "__main__":
    unittest.main()
