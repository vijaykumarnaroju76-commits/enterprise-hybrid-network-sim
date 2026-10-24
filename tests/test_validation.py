import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "automation"))
from generate_validation_report import count_ospf_neighbors, count_bgp_neighbors, render_report
from demo import scenarios


class ValidationTests(unittest.TestCase):
    def test_scenarios(self):
        for name, devices, ospf, bgp, expected in scenarios():
            with self.subTest(name=name):
                self.assertEqual(render_report(devices, ospf, bgp)[1], expected)

    def test_only_full_ospf_counts(self):
        self.assertEqual(count_ospf_neighbors({"status": "ok", "ospf_neighbors":
            [{"state": s} for s in ["FULL/DR", "FULL/-", "2WAY/DROTHER", "EXSTART/DR", "DOWN"]]}), 2)

    def test_zero_prefix_bgp_is_established(self):
        self.assertEqual(count_bgp_neighbors({"status": "ok", "bgp_summary":
            [{"state_pfxrcd": "0"}, {"state_pfxrcd": "Active"}]}), 1)

    def test_malformed_fails_closed(self):
        for value in [None, "raw output", {}, ["bad row"], [{}]]:
            for function, key in [(count_ospf_neighbors, "ospf_neighbors"),
                                  (count_bgp_neighbors, "bgp_summary")]:
                with self.subTest(value=value, key=key):
                    self.assertIsNone(function({"status": "ok", key: value}))

    def test_missing_device_fails(self):
        _, devices, ospf, bgp, _ = next(scenarios())
        del ospf["CORE-R1"]
        self.assertFalse(render_report(devices, ospf, bgp)[1])

    def test_unreachable_fails(self):
        self.assertIsNone(count_bgp_neighbors({"status": "unreachable"}))

    def test_empty_inventory_rejected(self):
        with self.assertRaises(ValueError):
            render_report([], {}, {})

    def test_duplicate_inventory_rejected(self):
        _, devices, ospf, bgp, _ = next(scenarios())
        with self.assertRaises(ValueError):
            render_report(devices + [devices[0]], ospf, bgp)

    def test_invalid_count_rejected(self):
        for value in [-1, True, "3", None]:
            _, devices, ospf, bgp, _ = next(scenarios())
            devices[0]["expected_bgp_neighbors"] = value
            with self.assertRaises(ValueError):
                render_report(devices, ospf, bgp)

    def test_branch_bgp_not_applicable(self):
        _, devices, ospf, bgp, _ = next(scenarios())
        bgp["SITE1-RTR"] = {"status": "ok", "bgp_summary": "BGP not configured"}
        text, passed = render_report(devices, ospf, bgp)
        self.assertTrue(passed)
        self.assertIn("N/A", text)


if __name__ == "__main__":
    unittest.main()
