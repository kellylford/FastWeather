import unittest

from fastweather.models.settings import AppSettings, default_config


class SettingsTests(unittest.TestCase):
    def test_defaults_present(self):
        cfg = default_config()
        self.assertIn("current", cfg)
        self.assertIn("units", cfg)
        self.assertEqual(cfg["units"]["temperature"], "F")

    def test_merge_overrides_saved_values(self):
        s = AppSettings()
        s.merge_saved({"units": {"temperature": "C"}, "current": {"pressure": True}})
        self.assertEqual(s["units"]["temperature"], "C")
        self.assertTrue(s["current"]["pressure"])
        # untouched defaults survive
        self.assertTrue(s["current"]["temperature"])

    def test_merge_ignores_unknown_sections(self):
        s = AppSettings()
        s.merge_saved({"bogus": {"x": 1}})
        self.assertNotIn("bogus", s.to_dict())

    def test_merge_preserves_new_keys_on_upgrade(self):
        # An old config missing a newer key still yields the default for it.
        s = AppSettings()
        s.merge_saved({"current": {"temperature": False}})
        self.assertFalse(s["current"]["temperature"])
        self.assertIn("uv_index", s["current"])  # newer key retains default


if __name__ == "__main__":
    unittest.main()
