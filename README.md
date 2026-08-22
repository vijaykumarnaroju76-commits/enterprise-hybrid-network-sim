# Enterprise Hybrid & Multi-Cloud Network Simulation

A simulated enterprise network — on-premises OSPF/BGP routing behind a Palo Alto perimeter, extended over redundant IPsec/BGP VPNs into both **AWS** and **Azure** — built as a GNS3 lab, documented like production, automated with Python/Ansible/pyATS, and provisioned in the cloud with Terraform.

```
                         INTERNET
                             |
                      ┌─────────────┐
                      │ Palo Alto   │
                      │  Firewall   │
                      └──────┬──────┘
                             |
                    ┌────────┴────────┐
                    │ Enterprise Core │
                    └────────┬────────┘
                         /         \
                       R1           R2
                        \           /
                         \   BGP   /
                          \       /
                    ┌──────┴───────┐
                    │              │
                   AWS           Azure
                    │              │
             Transit Gateway   VPN Gateway
                /       \        /       \
            Prod VPC   Dev VPC Prod VNet Dev VNet
```

Full topology, addressing, and redundancy design: [`documentation/architecture.md`](documentation/architecture.md).

## Why this exists

This isn't a checklist of buzzwords bolted onto a diagram. It's built in stages, each one runnable and independently defensible: a professional network design, then routing that actually redistributes and filters correctly, then real hybrid cloud connectivity, then nine deliberately-injected failures worked end-to-end, then automation that could actually catch those failures, then the Terraform that provisions the cloud half of it. Every document cross-references the others and reuses the same IP/ASN plan — nothing here is decorative.

## Repository structure

```
documentation/
  architecture.md          Topology, IP/VLAN plan, routing domains, security zones, traffic flows
  routing.md                OSPF + BGP + redistribution + filtering + redundancy, with show-command output
  cloud-networking.md       AWS (VPC/TGW/VPN) and Azure (VNet/UDR/VPN Gateway) design
  failure-scenarios/        9 incidents: SYMPTOM -> INVESTIGATION -> COMMANDS -> ROOT CAUSE -> FIX -> VALIDATION
  troubleshooting.md         General troubleshooting reference (OSPF/BGP/VPN/interfaces)
  validation-testing.md      Full test plan: OSPF, BGP, VPN, end-to-end, performance, failover, security
automation/
  collect_*.py, backup_configs.py, generate_validation_report.py   Netmiko collection scripts
  ansible/                   Pre/post-change validation playbooks (Genie-parsed state, diffed)
  pyats/                     Standalone pyATS/Genie pre/post check, usable as a CI gate
terraform/
  aws/                       Prod + Dev VPC, Transit Gateway, dual Site-to-Site VPN
  azure/                     Prod + Dev VNet, per-VNet VPN Gateway, UDRs
lab-notes/
  implementation-notes.md    Real-world lessons learned building this lab
scripts/
  route-verification.sh, traffic-analysis.sh, vpn-tunnel-test.sh    Reference verification scripts
```

## The build, in stages

| Stage | What it adds | Where |
|---|---|---|
| 1. Architecture | Clean topology, IP addressing, VLANs/subnets, routing domains, security zones, traffic flows | [`documentation/architecture.md`](documentation/architecture.md) |
| 2. Routing | OSPF + BGP, route redistribution, route filtering, redundancy, `show` command walkthroughs | [`documentation/routing.md`](documentation/routing.md) |
| 3. Cloud networking | On-prem -> AWS (VPC/subnets/route tables/TGW/VPN) -> Azure (VNet/subnets/UDR/VPN Gateway) | [`documentation/cloud-networking.md`](documentation/cloud-networking.md) |
| 4. Failure scenarios | 9 incidents worked end-to-end: BGP down, OSPF failure, bad advertisement, redistribution loop, VPN failure, NAT misconfig, firewall denial, asymmetric routing, cloud route-table error | [`documentation/failure-scenarios/`](documentation/failure-scenarios/) |
| 5. Automation | Netmiko collection + validation report, Ansible + pyATS/Genie pre/post-change validation | [`automation/`](automation/) |
| 6. Terraform | AWS and Azure provisioned as code, matching the design exactly | [`terraform/`](terraform/) |
| 7. Git workflow | Feature-branch -> PR -> merge process used to build all of the above | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

## Quick reference

- **Addressing/ASNs/router IDs**: all defined once in [`documentation/architecture.md`](documentation/architecture.md) — every other document reuses these values.
- **Redundancy model**: CORE-R1 is primary to AWS / backup to Azure; CORE-R2 is primary to Azure / backup to AWS. See [`documentation/routing.md`](documentation/routing.md) §5.
- **Run the automation**: see [`automation/README.md`](automation/README.md) for the Netmiko/Ansible/pyATS quick start.
- **Provision the cloud side**: see [`terraform/README.md`](terraform/README.md).
- **Contributing**: see [`CONTRIBUTING.md`](CONTRIBUTING.md) for the branch/PR workflow this repository itself was built with.

## Scope and honesty about simplifications

- On-prem is the hybrid hub — there is no direct AWS-to-Azure link. Cross-cloud traffic transits on-premises. This is deliberate (see [`documentation/architecture.md`](documentation/architecture.md) §7), not an oversight.
- Azure uses one VPN Gateway per VNet rather than a Virtual WAN hub (AWS Transit Gateway's rough equivalent). Called out explicitly in [`documentation/cloud-networking.md`](documentation/cloud-networking.md) §2.1 as a documented future enhancement, not an inconsistency.
- Devices in `documentation/` and `automation/` are simulated in GNS3; Terraform provisions real cloud resource *definitions* but this repository does not include live cloud credentials or state, and Terraform has never been applied against a real account from this repo.
