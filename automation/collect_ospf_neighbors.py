#!/usr/bin/env python3
"""Collect OSPF neighbor state from every device in inventory.yaml via
Netmiko (`show ip ospf neighbor`) and write it to automation/output/.
"""
from netmiko_common import run_on_all, write_output


def main():
    results = run_on_all("show ip ospf neighbor", "ospf_neighbors")
    write_output("ospf_neighbors", results)


if __name__ == "__main__":
    main()
