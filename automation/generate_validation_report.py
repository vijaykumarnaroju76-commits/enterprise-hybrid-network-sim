#!/usr/bin/env python3
"""Validate collected routing state; malformed or missing evidence fails closed."""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

BASE = Path(__file__).resolve().parent


def latest(prefix, output_dir):
    matches = sorted(output_dir.glob(f"{prefix}_*.json"))
    if not matches:
        raise ValueError(f"Missing {prefix} collection in {output_dir}")
    data = json.loads(matches[-1].read_text())
    if not isinstance(data, dict):
        raise ValueError(f"Invalid collection: {matches[-1]}")
    return data


def parsed_rows(result, key):
    if not isinstance(result, dict) or result.get("status") != "ok":
        return None
    rows = result.get(key)
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        return None
    return rows


def count_ospf_neighbors(result):
    rows = parsed_rows(result, "ospf_neighbors")
    if rows is None or any("state" not in row for row in rows):
        return None
    return sum(str(row["state"]).upper().split("/")[0] == "FULL" for row in rows)


def count_bgp_neighbors(result):
    rows = parsed_rows(result, "bgp_summary")
    if rows is None or any("state_pfxrcd" not in row for row in rows):
        return None
    return sum(str(row["state_pfxrcd"]).isascii() and
               str(row["state_pfxrcd"]).isdigit() for row in rows)


def validate_inventory(devices):
    if not isinstance(devices, list) or not devices:
        raise ValueError("Inventory must contain at least one device")
    names = set()
    for device in devices:
        if not isinstance(device, dict):
            raise ValueError("Inventory device must be an object")
        name = device.get("name")
        if not isinstance(name, str) or not name.strip() or name in names:
            raise ValueError("Device names must be nonempty and unique")
        names.add(name)
        for key in ("expected_ospf_neighbors", "expected_bgp_neighbors"):
            if type(device.get(key)) is not int or device[key] < 0:
                raise ValueError(f"{name}: {key} must be a nonnegative integer")


def render_report(devices, ospf, bgp, evidence_kind="collected"):
    validate_inventory(devices)
    if not isinstance(ospf, dict) or not isinstance(bgp, dict):
        raise ValueError("Collections must be objects keyed by device name")
    lines = ["# Validation Report", "",
             f"Generated: {datetime.now(timezone.utc).isoformat()}",
             f"Evidence: {evidence_kind}", "",
             "| Device | OSPF FULL (actual/minimum) | BGP established (actual/minimum) | Result |",
             "|---|---|---|---|"]
    passed = True
    for device in devices:
        name = device["name"]
        eo, eb = device["expected_ospf_neighbors"], device["expected_bgp_neighbors"]
        ao = count_ospf_neighbors(ospf.get(name))
        # BGP is not configured on branch routers. Mark it N/A explicitly.
        ab = count_bgp_neighbors(bgp.get(name)) if eb else 0
        if ao is None or ab is None:
            result = "FAIL (missing, unreachable, or unparsed evidence)"
        elif ao < eo or ab < eb:
            result = "FAIL (below expected)"
        else:
            result = "PASS"
        passed &= result == "PASS"
        bgp_cell = f"{ab if ab is not None else '?'}/{eb}" if eb else "N/A"
        safe_name = name.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {safe_name} | {ao if ao is not None else '?'}/{eo} | {bgp_cell} | {result} |")
    lines.extend(["", f"## Overall: {'PASS' if passed else 'FAIL'}", "",
                  "This checks minimum neighbor counts only, not peer identity, routes, VPN health, or end-to-end reachability."])
    return "\n".join(lines) + "\n", passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, default=BASE / "inventory.yaml")
    parser.add_argument("--output-dir", type=Path, default=BASE / "output")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = args.report or args.output_dir / "validation_report.md"
    try:
        import yaml
        inventory = yaml.safe_load(args.inventory.read_text())
        if not isinstance(inventory, dict):
            raise ValueError("Inventory must be an object containing devices")
        text, passed = render_report(inventory.get("devices"),
                                     latest("ospf_neighbors", args.output_dir),
                                     latest("bgp_neighbors", args.output_dir))
    except (OSError, ValueError, yaml.YAMLError) as exc:
        text, passed = f"# Validation Report\n\n## Overall: FAIL\n\nInput error: {exc}\n", False
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(text)
    print(f"Wrote {report}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
