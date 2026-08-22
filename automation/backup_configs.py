#!/usr/bin/env python3
"""Back up the running configuration of every device in inventory.yaml via
Netmiko (`show running-config`) to timestamped text files under
automation/output/configs/. Intended to run before any change window, and
by the pre_change_validation Ansible/pyATS workflows.
"""
from datetime import datetime, timezone
from pathlib import Path

from netmiko_common import connect, load_inventory

OUTPUT_DIR = Path(__file__).parent / "output" / "configs"


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for device in load_inventory():
        name = device["name"]
        try:
            conn = connect(device)
            running_config = conn.send_command("show running-config")
            conn.disconnect()
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"{name}: FAILED ({exc})")
            continue
        path = OUTPUT_DIR / f"{name}_{timestamp}.cfg"
        path.write_text(running_config)
        print(f"{name}: backed up to {path}")


if __name__ == "__main__":
    main()
