#!/usr/bin/env python3
"""Collect the routing table from every device in inventory.yaml via
Netmiko (`show ip route`) and write it to automation/output/.
"""
from netmiko_common import run_on_all, write_output


def main():
    results = run_on_all("show ip route", "routes")
    write_output("routes", results)


if __name__ == "__main__":
    main()
