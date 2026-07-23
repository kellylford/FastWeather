import unittest

from fastweather.models import mydata
from fastweather.models.settings import AppSettings
from fastweather.services import mydata_service
from fastweather.ui.formatters import Formatter


class MyDataCatalogTests(unittest.TestCase):
    def test_keys_unique(self):
        keys = [p.key for p in mydata.CATALOG]
        self.assertEqual(len(keys), len(set(keys)))

    def test_categories_ordered_unique(self):
        cats = mydata.categories()
        self.assertEqual(len(cats), len(set(cats)))
        self.assertIn("Air Quality", cats)
        self.assertIn("Marine & Ocean", cats)

    def test_endpoints_valid(self):
        for p in mydata.CATALOG:
            self.assertIn(p.endpoint, ("forecast", "marine", "air_quality"))


class FormatValueTests(unittest.TestCase):
    def setUp(self):
        self.fmt = Formatter(AppSettings())

    def test_none(self):
        p = mydata.CATALOG_BY_KEY["temperature_2m"]
        self.assertEqual(mydata.format_value(p, None, self.fmt), "N/A")

    def test_temperature(self):
        p = mydata.CATALOG_BY_KEY["temperature_2m"]
        self.assertEqual(mydata.format_value(p, 20.0, self.fmt), "68.0°F")

    def test_raw_with_unit(self):
        p = mydata.CATALOG_BY_KEY["pm2_5"]
        self.assertEqual(mydata.format_value(p, 12.5, self.fmt), "12.5 µg/m³")

    def test_raw_trims_trailing_zeros(self):
        p = mydata.CATALOG_BY_KEY["cape"]
        self.assertEqual(mydata.format_value(p, 0.0, self.fmt), "0 J/kg")


class ExtractTests(unittest.TestCase):
    def test_picks_current_hour(self):
        results, errors = {}, {}
        data = {
            "hourly": {
                "time": ["2026-07-22T00:00", "2026-07-22T01:00"],
                "cape": [11.0, 22.0],
            }
        }
        mydata_service._extract(data, ["cape"], "2026-07-22T01:00", results, errors, "forecast")
        self.assertEqual(results["cape"], 22.0)


if __name__ == "__main__":
    unittest.main()
