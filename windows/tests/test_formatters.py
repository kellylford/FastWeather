import unittest

from fastweather.models.settings import AppSettings
from fastweather.ui.formatters import Formatter, degrees_to_cardinal


class FormatterTests(unittest.TestCase):
    def _fmt(self, temp="F", wind="mph", precip="in"):
        s = AppSettings()
        s["units"] = {"temperature": temp, "wind_speed": wind, "precipitation": precip}
        return Formatter(s)

    def test_temperature_fahrenheit(self):
        self.assertEqual(self._fmt().temperature(20.0), "68.0°F")

    def test_temperature_values(self):
        f = self._fmt(temp="F")
        self.assertEqual(f.temperature(0.0), "32.0°F")
        self.assertEqual(f.temperature_short(20.0), "68°F")
        c = self._fmt(temp="C")
        self.assertEqual(c.temperature(20.0), "20.0°C")
        self.assertEqual(c.temperature_short(20.4), "20°C")

    def test_wind(self):
        self.assertEqual(self._fmt(wind="mph").wind_speed(100.0), "62.1 mph")
        self.assertEqual(self._fmt(wind="km/h").wind_speed(100.0), "100.0 km/h")

    def test_precipitation(self):
        self.assertEqual(self._fmt(precip="mm").precipitation(10.0), "10.0mm")
        self.assertEqual(self._fmt(precip="in").precipitation(25.4), '1.00"')

    def test_wind_ms(self):
        f = self._fmt(wind="m/s")
        self.assertEqual(f.wind_speed(36.0), "10.0 m/s")

    def test_pressure(self):
        s = AppSettings()
        s["units"]["pressure"] = "inHg"
        self.assertEqual(Formatter(s).pressure(1013.25), "29.92 inHg")
        s["units"]["pressure"] = "hPa"
        self.assertEqual(Formatter(s).pressure(1013.25), "1013 hPa")
        s["units"]["pressure"] = "mmHg"
        self.assertEqual(Formatter(s).pressure(1013.25), "760 mmHg")

    def test_distance(self):
        s = AppSettings()
        s["units"]["distance"] = "mi"
        self.assertEqual(Formatter(s).distance(1609.34), "1.0 mi")
        s["units"]["distance"] = "km"
        self.assertEqual(Formatter(s).distance(1000.0), "1.0 km")

    def test_cardinal(self):
        self.assertEqual(degrees_to_cardinal(0), "N")
        self.assertEqual(degrees_to_cardinal(90), "E")
        self.assertEqual(degrees_to_cardinal(180), "S")
        self.assertEqual(degrees_to_cardinal(270), "W")
        self.assertEqual(degrees_to_cardinal(360), "N")


if __name__ == "__main__":
    unittest.main()
