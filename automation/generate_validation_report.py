#!/usr/bin/env python3
"""Read the most recent output from collect_interfaces.py,
collect_bgp_neighbors.py, and collect_ospf_neighbors.py, cross-check each
device's actual neighbor counts against the expected counts in
inventory.yaml (which mirror documentation/architecture.md and
documentation/routing.md), and write a pass/fail Markdown report.

This is the automated version of manually reading through the "show ip
ospf neighbor" / "show ip bgp summary" output in documentation/routing.md
section 6 — same expected state, checked by a script instead of an eye.
"""
import glob
import json
from datetime import datetime, timezone
from pathlib import Path

from netmiko_common import OUTPUT_DIR, load_inventory

REPORT_PATH = Path(__file__).parent / "output" / "validation_report.md"


def latest(prefix):
    matches = sorted(glob.glob(str(OUTPUT_DIR / f"{prefix}_*.json")))
    if not matches:
        return None
    with open(matches[-1]) as f:
        return json.load(f)


def count_ospf_neighbors(device_result):
    if device_result.get("status") != "ok":
        return None
    return len(device_result.get("ospf_neighbors", []) or [])


def count_bgp_neighbors(device_result):
    if device_result.get("status") != "ok":
        return None
    bgp = device_result.get("bgp_summary", [])
    # textfsm output for "show ip bgp summary" is a list of neighbor rows;
    # count only rows whose state looks like an established session (a
    # digit, i.e. prefix count) rather than Idle/Active/Connect.
    return sum(1 for row in bgp if str(row.get("state_pfxrcd", "")).isdigit())


def main():
    ospf_data = latest("ospf_neighbors")
    bgp_data = latest("bgp_neighbors")

    if ospf_data is None or bgp_data is None:
        raise SystemExit(
            "No collected data found — run collect_ospf_neighbors.py and "
            "collect_bgp_neighbors.py first."
        )

    lines = [
        "# Validation Report",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "| Device | OSPF Neighbors (actual/expected) | BGP Neighbors (actual/expected) | Result |",
        "|---|---|---|---|",
    ]

    overall_pass = True
    for device in load_inventory():
        name = device["name"]
        expected_ospf = device["expected_ospf_neighbors"]
        expected_bgp = device["expected_bgp_neighbors"]

        actual_ospf = count_ospf_neighbors(ospf_data.get(name, {}))
        actual_bgp = count_bgp_neighbors(bgp_data.get(name, {}))

        if actual_ospf is None or actual_bgp is None:
            result = "FAIL (unreachable)"
            overall_pass = False
        elif actual_ospf < expected_ospf or actual_bgp < expected_bgp:
            result = "FAIL (below expected)"
            overall_pass = False
        else:
            result = "PASS"

        lines.append(
            f"| {name} | {actual_ospf if actual_ospf is not None else '?'}/{expected_ospf} "
            f"| {actual_bgp if actual_bgp is not None else '?'}/{expected_bgp} | {result} |"
        )

    lines += [
        "",
        f"## Overall: {'PASS' if overall_pass else 'FAIL'}",
    ]

    REPORT_PATH.parent.mkdir(exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines) + "\n")
    print(f"Wrote {REPORT_PATH}")
    if not overall_pass:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
