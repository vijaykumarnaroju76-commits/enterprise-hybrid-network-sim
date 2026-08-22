# Automation

Python/Netmiko collection scripts, an Ansible pre/post-change validation workflow, and a pyATS/Genie testbed — all driven against the six on-prem devices defined in [`inventory.yaml`](inventory.yaml), which mirrors the router-ID/loopback plan in [../documentation/architecture.md](../documentation/architecture.md).

```
Network
   |
   v
Python / Netmiko  (collect_*.py)
   |
   v
Collect
  - Interfaces
  - BGP neighbors
  - OSPF neighbors
  - Routes
  - Configurations (backup_configs.py)
   |
   v
Validation Report  (generate_validation_report.py)
```

Then, for change control:

```
Ansible + pyATS/Genie
  pre_change_validation.yml   -> snapshot state before a change
  <make the change>
  post_change_validation.yml  -> snapshot state after, diff against pre-change
```

## Layout

```
automation/
  requirements.txt
  inventory.yaml                    # Netmiko-style device inventory
  collect_interfaces.py
  collect_bgp_neighbors.py
  collect_ospf_neighbors.py
  collect_routes.py
  backup_configs.py
  generate_validation_report.py
  ansible/
    ansible.cfg
    inventory/hosts.yaml
    playbooks/
      collect_state.yml
      pre_change_validation.yml
      post_change_validation.yml
  pyats/
    testbed.yaml
    pre_post_check.py
```

## Quick start

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Credentials are never hardcoded — export them as environment variables
export NET_USERNAME=automation
export NET_PASSWORD='use a vault in real deployments'

python3 collect_interfaces.py
python3 collect_bgp_neighbors.py
python3 collect_ospf_neighbors.py
python3 collect_routes.py
python3 generate_validation_report.py
```

Each `collect_*.py` script writes timestamped JSON under `automation/output/` (git-ignored); `generate_validation_report.py` reads the latest of each and produces a single pass/fail Markdown report cross-checked against the expected state documented in [../documentation/routing.md](../documentation/routing.md) §6 — e.g. it flags any device with fewer than the expected OSPF/BGP neighbor count, which is the same signal a human would look for while working through the [failure scenarios](../documentation/failure-scenarios/).

## Ansible pre/post-change validation

```bash
cd ansible
ansible-playbook -i inventory/hosts.yaml playbooks/pre_change_validation.yml
# ... perform the change ...
ansible-playbook -i inventory/hosts.yaml playbooks/post_change_validation.yml
```
Post-change compares the new Genie-parsed state against the pre-change snapshot and fails the play if OSPF/BGP neighbor counts dropped or the routing table lost prefixes it had before — the automated equivalent of the "VALIDATION" step in every [failure scenario runbook](../documentation/failure-scenarios/).

## pyATS/Genie

`pyats/testbed.yaml` describes the same six devices in pyATS testbed format. `pyats/pre_post_check.py` is a standalone script usable outside Ansible for the same pre/post diff, e.g. from a CI pipeline gate before merging a config-change PR.
