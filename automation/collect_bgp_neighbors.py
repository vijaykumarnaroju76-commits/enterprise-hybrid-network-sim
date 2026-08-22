#!/usr/bin/env python3
"""Collect BGP neighbor state from every device in inventory.yaml via
Netmiko (`show ip bgp summary`) and write it to automation/output/.

Only CORE-R1 and CORE-R2 run BGP (see documentation/routing.md section 2);
branch routers are expected to return an empty/unsupported result, which
generate_validation_report.py treats as expected, not a failure.
"""
from netmiko_common import run_on_all, write_output


def main():
    results = run_on_all("show ip bgp summary", "bgp_summary")
    write_output("bgp_neighbors", results)


if __name__ == "__main__":
    main()
