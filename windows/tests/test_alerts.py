import unittest
from datetime import datetime, timedelta, timezone

from fastweather.models import alert as A
from fastweather.services import alert_service, nws


def _future(hours=6):
    return (datetime.now(timezone.utc) + timedelta(hours=hours)).isoformat()


def _past(hours=6):
    return (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()


class HazardTests(unittest.TestCase):
    def test_classification_order(self):
        cases = {
            "Tornado Warning": "Storms",
            "Hurricane Warning": "Tropical",
            "Winter Storm Warning": "Winter",   # winter before storms/heat
            "Excessive Heat Warning": "Heat",
            "Air Quality Alert": "Air Quality",
            "Flood Warning": "Flooding",
            "High Wind Warning": "Wind",
            "Small Craft Advisory": "Marine & Coastal",
            "Dense Fog Advisory": "Fog",
            "Rip Current Statement": "Marine & Coastal",
        }
        for event, expected in cases.items():
            self.assertEqual(A.classify_hazard(event), expected, event)


class SeverityFilterTests(unittest.TestCase):
    def test_exclusive(self):
        self.assertTrue(A.severity_filter_includes("All", "Minor"))
        self.assertTrue(A.severity_filter_includes("Severe", "Severe"))
        self.assertFalse(A.severity_filter_includes("Severe", "Extreme"))
        self.assertFalse(A.severity_filter_includes("Moderate", "Severe"))


class DigestTests(unittest.TestCase):
    def _mk(self, event, sev, area):
        return A.WeatherAlert(event, sev, "", "", "", "", _future(), area)

    def test_group_and_sort(self):
        alerts = [
            self._mk("Flood Warning", "Severe", "A"),
            self._mk("Flood Warning", "Severe", "B"),
            self._mk("Tornado Warning", "Extreme", "C"),
        ]
        groups = A.build_digest(alerts, "All", None)
        # Extreme first despite fewer areas
        self.assertEqual(groups[0].event, "Tornado Warning")
        self.assertEqual(groups[0].count, 1)
        self.assertEqual(groups[1].event, "Flood Warning")
        self.assertEqual(groups[1].count, 2)

    def test_severity_filter(self):
        alerts = [self._mk("Flood Warning", "Severe", "A"),
                  self._mk("Heat Advisory", "Minor", "B")]
        groups = A.build_digest(alerts, "Severe", None)
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0].severity, "Severe")

    def test_hazard_filter(self):
        alerts = [self._mk("Flood Warning", "Severe", "A"),
                  self._mk("High Wind Warning", "Severe", "B")]
        groups = A.build_digest(alerts, "All", "Flooding")
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0].event, "Flood Warning")


class ExpiryTests(unittest.TestCase):
    def test_expired(self):
        a = A.WeatherAlert("X", "Severe", "", "", "", "", _past(), "")
        self.assertTrue(a.is_expired())

    def test_active(self):
        a = A.WeatherAlert("X", "Severe", "", "", "", "", _future(), "")
        self.assertFalse(a.is_expired())

    def test_no_end_kept(self):
        a = A.WeatherAlert("X", "Severe", "", "", "", "", "", "")
        self.assertFalse(a.is_expired())


class NWSParseTests(unittest.TestCase):
    def test_parse_and_area_labeling(self):
        feature = {"properties": {
            "id": "x1", "event": "Flood Warning", "severity": "Severe",
            "areaDesc": "Dane", "onset": _past(1), "ends": _future(),
            "geocode": {"UGC": ["WIC025", "WIC021"]},
        }}
        a = nws.parse_feature(feature)
        self.assertEqual(a.severity, "Severe")
        self.assertEqual(a.area, "Dane, WI")
        self.assertEqual(a.source, "NWS")

    def test_air_quality_severity_promotion(self):
        feature = {"properties": {"event": "Air Quality Alert", "severity": "Unknown",
                                  "areaDesc": "Zone", "ends": _future()}}
        self.assertEqual(nws.parse_feature(feature).severity, "Moderate")

    def test_ends_clamped_to_onset(self):
        feature = {"properties": {"event": "X", "onset": _future(5), "ends": _future(1),
                                  "areaDesc": "Z"}}
        a = nws.parse_feature(feature)
        self.assertEqual(a.ends, a.onset)  # ends before onset -> clamped


class AlertServiceTests(unittest.TestCase):
    def setUp(self):
        self._orig = alert_service.http.get_json

    def tearDown(self):
        alert_service.http.get_json = self._orig

    def test_filters_expired_and_sorts(self):
        alert_service.http.get_json = lambda *a, **k: {"features": [
            {"properties": {"event": "Old", "severity": "Extreme", "areaDesc": "A",
                            "ends": _past()}},
            {"properties": {"event": "Minor Now", "severity": "Minor", "areaDesc": "B",
                            "ends": _future()}},
            {"properties": {"event": "Severe Now", "severity": "Severe", "areaDesc": "C",
                            "ends": _future()}},
        ]}
        alerts = alert_service.fetch_alerts(9.0, 9.0, use_cache=False)
        self.assertEqual([a.event for a in alerts], ["Severe Now", "Minor Now"])

    def test_error_none(self):
        def boom(*a, **k):
            raise RuntimeError("down")
        alert_service.http.get_json = boom
        self.assertIsNone(alert_service.has_active_alerts(9.0, 9.0))


if __name__ == "__main__":
    unittest.main()
