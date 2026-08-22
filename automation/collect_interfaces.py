#!/usr/bin/env python3
"""Collect interface status from every device in inventory.yaml via Netmiko
(`show ip interface brief`) and write it to automation/output/.
"""
from netmiko_common import run_on_all, write_output


def main():
    results = run_on_all("show ip interface brief", "interfaces")
    write_output("interfaces", results)


if __name__ == "__main__":
    main()
