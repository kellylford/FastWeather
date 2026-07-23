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

    def test_update_available_picks_newest_windows_release(self):
        updater.http.get_json = lambda url: [
            # newest windows release
            {"tag_name": "windows-v3.1.0", "body": "Notes", "assets": [
                {"name": "WeatherFast.exe", "browser_download_url": "http://x/WeatherFast.exe"},
                {"name": "WeatherFast-3.1.0-Setup.exe",
                 "browser_download_url": "http://x/WeatherFast-3.1.0-Setup.exe"},
            ]},
            {"tag_name": "windows-v3.0.0", "assets": []},
            # non-windows releases must be ignored
            {"tag_name": "ios-v1.6.0", "assets": []},
            {"tag_name": "web-v2.0.0", "assets": []},
        ]
        info = updater.check_for_update("3.0.0")
        self.assertEqual(info["version"], "3.1.0")
        self.assertTrue(info["url"].endswith("Setup.exe"))
        self.assertEqual(info["notes"], "Notes")

    def test_ignores_non_windows_and_prerelease(self):
        updater.http.get_json = lambda url: [
            {"tag_name": "ios-v9.9.9", "assets": []},
            {"tag_name": "web-v9.9.9", "assets": []},
            {"tag_name": "windows-v9.9.9", "prerelease": True, "assets": []},
        ]
        self.assertIsNone(updater.check_for_update("3.0.0"))

    def test_no_update_when_not_newer(self):
        updater.http.get_json = lambda url: [{"tag_name": "windows-v3.0.0", "assets": []}]
        self.assertIsNone(updater.check_for_update("3.0.0"))

    def test_update_without_installer_asset(self):
        updater.http.get_json = lambda url: [{"tag_name": "windows-v4.0.0", "assets": []}]
        info = updater.check_for_update("3.0.0")
        self.assertEqual(info["version"], "4.0.0")
        self.assertIsNone(info["url"])


if __name__ == "__main__":
    unittest.main()
