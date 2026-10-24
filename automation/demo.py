#!/usr/bin/env python3
"""Offline synthetic routing demo. No network connections or cloud resources."""
import argparse
import copy
from pathlib import Path

from generate_validation_report import render_report


def scenarios():
    devices = [{"name": name, "expected_ospf_neighbors": ospf,
                "expected_bgp_neighbors": bgp}
               for name, ospf, bgp in [("CORE-R1", 3, 3), ("CORE-R2", 3, 3),
                                     ("SITE1-RTR", 1, 0), ("SITE2-RTR", 1, 0),
                                     ("SITE3-RTR", 1, 0), ("SITE4-RTR", 1, 0)]]
    ospf = {d["name"]: {"status": "ok", "ospf_neighbors":
            [{"state": "FULL/DR"} for _ in range(d["expected_ospf_neighbors"])]}
            for d in devices}
    bgp = {d["name"]: {"status": "ok", "bgp_summary":
           [{"state_pfxrcd": "4"} for _ in range(d["expected_bgp_neighbors"])]}
           for d in devices}
    yield "healthy", devices, ospf, bgp, True
    failed = copy.deepcopy(ospf)
    failed["CORE-R1"]["ospf_neighbors"][0]["state"] = "EXSTART/DR"
    yield "ospf-incomplete", devices, failed, bgp, False
    failed_bgp = copy.deepcopy(bgp)
    failed_bgp["CORE-R2"]["bgp_summary"][0]["state_pfxrcd"] = "Active"
    yield "bgp-down", devices, ospf, failed_bgp, False
    raw = copy.deepcopy(ospf)
    raw["SITE1-RTR"]["ospf_neighbors"] = "Unparsed show command output"
    yield "unparsed-output", devices, raw, bgp, False
    yield "recovered", devices, ospf, bgp, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parent / "output" / "demo")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    correct = True
    for name, devices, ospf, bgp, expected in scenarios():
        text, passed = render_report(devices, ospf, bgp, "SYNTHETIC OFFLINE DEMO — not captured lab evidence")
        (args.output_dir / f"{name}.md").write_text(text)
        print(f"{name}: {'PASS' if passed else 'FAIL'} (expected {'PASS' if expected else 'FAIL'})")
        correct &= passed == expected
    return 0 if correct else 1


if __name__ == "__main__":
    raise SystemExit(main())
