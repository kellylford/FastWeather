import unittest

from fastweather.services import updater


class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self._orig = updater.http.get_json

    def tearDown(self):
        updater.http.get_json = self._orig

    def test_version_compare(self):
        self.assertTrue(updater.is_newer("1.2", "1.1"))
        self.assertTrue(updater.is_newer("1.10", "1.9"))
        self.assertTrue(updater.is_newer("2.0.0", "1.9.9"))
        self.assertFalse(updater.is_newer("1.1", "1.1"))
        self.assertFalse(updater.is_newer("1.0", "1.1"))
        # zero-padded: 1.1.0 is not newer than 1.1 (avoids spurious update prompt)
        self.assertFalse(updater.is_newer("1.1.0", "1.1"))
        self.assertFalse(updater.is_newer("1.1", "1.1.0"))
        self.assertTrue(updater.is_newer("1.1.1", "1.1"))

    def test_update_available_with_installer_asset(self):
        updater.http.get_json = lambda url: {
            "tag_name": "v2.0", "body": "Notes",
            "assets": [
                {"name": "WeatherFast.exe",
                 "browser_download_url": "http://x/WeatherFast.exe"},
                {"name": "WeatherFast-2.0-Setup.exe",
                 "browser_download_url": "http://x/WeatherFast-2.0-Setup.exe"},
            ],
        }
        info = updater.check_for_update("1.1")
        self.assertEqual(info["version"], "2.0")
        self.assertTrue(info["url"].endswith("Setup.exe"))  # picked the installer asset
        self.assertEqual(info["notes"], "Notes")

    def test_no_update_when_not_newer(self):
        updater.http.get_json = lambda url: {"tag_name": "v1.1", "assets": []}
        self.assertIsNone(updater.check_for_update("1.1"))

    def test_update_without_installer_asset(self):
        updater.http.get_json = lambda url: {"tag_name": "v3.0", "assets": []}
        info = updater.check_for_update("1.1")
        self.assertEqual(info["version"], "3.0")
        self.assertIsNone(info["url"])


if __name__ == "__main__":
    unittest.main()
