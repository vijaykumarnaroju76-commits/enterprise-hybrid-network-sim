# Contributing / Git Workflow

This repository is built and evolved one feature branch at a time. Every upgrade — a new document, a routing change, a Terraform module, a new failure scenario — gets its own branch, its own PR, and its own review before it lands on `main`. This is what actually produced this repository's own history and is the expected workflow for anything added to it going forward.

## Branch naming

`feature/<short-description>`, e.g.:

```
feature/project-readme
feature/network-topology
feature/bgp-routing
feature/aws-connectivity
feature/azure-connectivity
feature/failure-scenarios
feature/netmiko-automation
feature/terraform-aws
feature/terraform-azure
```

One logical change per branch. A branch that touches routing docs *and* unrelated Terraform variables is two PRs, not one.

## Workflow

```bash
git checkout main
git pull

git checkout -b feature/<short-description>

# ... make changes ...

git add <files>
git commit -m "Clear, descriptive message"
git push -u origin feature/<short-description>
```

Then open a pull request targeting `main`. Once it's reviewed and merged, delete the branch and start the next one from an up-to-date `main`:

```bash
git checkout main
git pull
git checkout -b feature/<next-short-description>
```

## Commit messages

Describe *why*, not just *what* — "Add Azure VPN Gateway backup connection for CORE-R1 failover" beats "update vpn-gateway.tf". If a commit fixes a failure scenario described in [`documentation/failure-scenarios/`](documentation/failure-scenarios/), reference it (e.g. "per failure-scenarios/04-route-redistribution-loop.md").

## What every PR should keep consistent

This project has a lot of interlocking numbers — ASNs, CIDRs, router IDs — defined once in [`documentation/architecture.md`](documentation/architecture.md) and reused everywhere else (routing config, cloud Terraform, automation inventory, failure-scenario walkthroughs). Before opening a PR that touches addressing:

1. Update `documentation/architecture.md` first — it's the source of truth.
2. Grep the rest of the repo for the old value and update every reference (`documentation/routing.md`, `documentation/cloud-networking.md`, `terraform/*/variables.tf`, `automation/inventory.yaml`, `automation/ansible/inventory/hosts.yaml`, `automation/pyats/testbed.yaml`).
3. Check whether any [failure scenario](documentation/failure-scenarios/) references the value in its "expected" output and update it too.

## Review checklist

- [ ] Does this change match the numbering in `documentation/architecture.md`, or does it update that file first?
- [ ] If this adds/changes routing or cloud config, is `documentation/routing.md` or `documentation/cloud-networking.md` updated to match?
- [ ] Are secrets (PSKs, credentials, account IDs) kept out of the diff — environment variables or `*.tfvars`/`*.tfvars.example` per `.gitignore`, never hardcoded?
- [ ] Do the automation scripts (`automation/`) still reflect the current device inventory if a site/router was added or renamed?
- [ ] For a new failure scenario: does it follow SYMPTOM → INVESTIGATION → COMMANDS → ROOT CAUSE → FIX → VALIDATION?

## Project history (for reference)

The upgrades below were built in this order, each as its own branch/PR against `main`:

1. `feature/project-readme` — root README and repository structure
2. `feature/network-topology` — [`documentation/architecture.md`](documentation/architecture.md): topology, IP plan, VLANs, security zones, traffic flows
3. `feature/bgp-routing` — [`documentation/routing.md`](documentation/routing.md): OSPF + BGP, redistribution, filtering, redundancy
4. `feature/aws-connectivity` / `feature/azure-connectivity` — [`documentation/cloud-networking.md`](documentation/cloud-networking.md)
5. `feature/failure-scenarios` — [`documentation/failure-scenarios/`](documentation/failure-scenarios/)
6. `feature/netmiko-automation` — [`automation/`](automation/)
7. `feature/terraform-aws` / `feature/terraform-azure` — [`terraform/`](terraform/)
