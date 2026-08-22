"""Shared helpers for the collect_*.py scripts: inventory loading, Netmiko
connection handling, and JSON output writing. Not a script on its own.
"""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml
from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException

INVENTORY_PATH = Path(__file__).parent / "inventory.yaml"
OUTPUT_DIR = Path(__file__).parent / "output"


def load_inventory():
    with open(INVENTORY_PATH) as f:
        return yaml.safe_load(f)["devices"]


def credentials():
    username = os.environ.get("NET_USERNAME")
    password = os.environ.get("NET_PASSWORD")
    if not username or not password:
        sys.exit(
            "NET_USERNAME and NET_PASSWORD must be set in the environment "
            "(never hardcode credentials in inventory.yaml or scripts)."
        )
    return username, password


def connect(device):
    username, password = credentials()
    return ConnectHandler(
        device_type=device["device_type"],
        host=device["host"],
        username=username,
        password=password,
        timeout=10,
    )


def run_on_all(command, parse_key):
    """Runs `command` on every device in the inventory and returns a dict
    keyed by device name. Connection failures are recorded, not raised, so
    one unreachable device doesn't abort collection against the rest.
    """
    results = {}
    for device in load_inventory():
        name = device["name"]
        try:
            conn = connect(device)
            output = conn.send_command(command, use_textfsm=True)
            conn.disconnect()
            results[name] = {"status": "ok", parse_key: output}
        except (NetmikoAuthenticationException, NetmikoTimeoutException) as exc:
            results[name] = {"status": "unreachable", "error": str(exc)}
    return results


def write_output(prefix, data):
    OUTPUT_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = OUTPUT_DIR / f"{prefix}_{timestamp}.json"
    with open(path, "w") as f:
        json.dump(data, f, indent=2, default=str)
    print(f"Wrote {path}")
    return path
