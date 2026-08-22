#!/usr/bin/env python3
"""pyATS/Genie pre- and post-change validation, standalone (no Ansible
required) — usable directly from a CI pipeline as a merge gate on a
config-change PR.

Usage:
    python3 pre_post_check.py pre    # snapshot before the change
    python3 pre_post_check.py post   # snapshot after, diff against 'pre'

Parses "show ip ospf neighbor" and "show ip bgp summary" with Genie into
structured data, rather than scraping raw text, and fails (non-zero exit)
if neighbor counts regress between the two snapshots — the same
pass/fail logic as automation/generate_validation_report.py, but sourced
from Genie parsers instead of TextFSM/Netmiko, and gated on a diff rather
than a fixed expected count.
"""
import json
import sys
from pathlib import Path

from genie.testbed import load

TESTBED_PATH = Path(__file__).parent / "testbed.yaml"
SNAPSHOT_DIR = Path(__file__).parent / "snapshots"


def snapshot():
    testbed = load(str(TESTBED_PATH))
    state = {}
    for name, device in testbed.devices.items():
        device.connect(log_stdout=False)
        entry = {}
        try:
            entry["ospf_neighbor"] = device.parse("show ip ospf neighbor")
        except Exception as exc:  # noqa: BLE001
            entry["ospf_neighbor"] = {"error": str(exc)}
        if name in ("CORE-R1", "CORE-R2"):
            try:
                entry["bgp_summary"] = device.parse("show ip bgp summary")
            except Exception as exc:  # noqa: BLE001
                entry["bgp_summary"] = {"error": str(exc)}
        device.disconnect()
        state[name] = entry
    return state


def neighbor_count(entry, key):
    data = entry.get(key, {})
    if "error" in data:
        return None
    if key == "ospf_neighbor":
        interfaces = data.get("interfaces", {})
        return sum(len(i.get("neighbors", {})) for i in interfaces.values())
    if key == "bgp_summary":
        neighbors = data.get("vrf", {}).get("default", {}).get("neighbor", {})
        return len(neighbors)
    return None


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("pre", "post"):
        sys.exit("Usage: pre_post_check.py [pre|post]")

    SNAPSHOT_DIR.mkdir(exist_ok=True)
    mode = sys.argv[1]
    state = snapshot()

    if mode == "pre":
        (SNAPSHOT_DIR / "pre.json").write_text(json.dumps(state, indent=2, default=str))
        print("Pre-change snapshot written.")
        return

    pre_path = SNAPSHOT_DIR / "pre.json"
    if not pre_path.exists():
        sys.exit("No pre-change snapshot found — run with 'pre' first.")
    pre_state = json.loads(pre_path.read_text())

    failures = []
    for name, post_entry in state.items():
        pre_entry = pre_state.get(name, {})
        for key in ("ospf_neighbor", "bgp_summary"):
            if key not in post_entry:
                continue
            pre_count = neighbor_count(pre_entry, key)
            post_count = neighbor_count(post_entry, key)
            if pre_count is None or post_count is None:
                failures.append(f"{name}: could not parse {key} pre/post")
            elif post_count < pre_count:
                failures.append(f"{name}: {key} dropped {pre_count} -> {post_count}")

    (SNAPSHOT_DIR / "post.json").write_text(json.dumps(state, indent=2, default=str))

    if failures:
        print("FAIL:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("PASS: no neighbor regressions between pre- and post-change snapshots.")


if __name__ == "__main__":
    main()
