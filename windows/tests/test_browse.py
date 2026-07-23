import unittest

from fastweather import browse_favorites as bf


class BrowseFavoritesTests(unittest.TestCase):
    def test_toggle_add_remove(self):
        favs = []
        favs, added = bf.toggle(favs, "us", "Wisconsin")
        self.assertTrue(added)
        self.assertTrue(bf.is_favorite(favs, "us", "Wisconsin"))
        favs, added = bf.toggle(favs, "us", "Wisconsin")
        self.assertFalse(added)
        self.assertFalse(bf.is_favorite(favs, "us", "Wisconsin"))

    def test_kind_distinguishes(self):
        favs = [{"kind": "us", "region": "Georgia"}]
        self.assertFalse(bf.is_favorite(favs, "intl", "Georgia"))
        self.assertTrue(bf.is_favorite(favs, "us", "Georgia"))


if __name__ == "__main__":
    unittest.main()
