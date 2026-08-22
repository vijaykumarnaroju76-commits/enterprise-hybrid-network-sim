# Enterprise Hybrid Multi-Cloud Network Simulation

[![Network Infrastructure CI](https://github.com/vijaykumarnaroju76-commits/enterprise-hybrid-network-sim/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/vijaykumarnaroju76-commits/enterprise-hybrid-network-sim/actions/workflows/ci.yml)

> Production-style network engineering lab connecting an on-premises enterprise to **AWS** and **Azure** with redundant routing, infrastructure as code, automation, and failure-driven troubleshooting.

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Hybrid_Networking-232F3E?logo=amazonaws&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-Hybrid_Networking-0078D4?logo=microsoftazure&logoColor=white)
![Python](https://img.shields.io/badge/Python-Network_Automation-3776AB?logo=python&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible&logoColor=white)
![Status](https://img.shields.io/badge/Terraform-Validated-success)

## What I Built

I designed this project to model the type of hybrid environment a network/cloud engineer may support in production:

- Multi-area **OSPF** enterprise routing with redundant core routers
- **BGP** connectivity between the enterprise, AWS, and Azure
- Redundant **IPsec Site-to-Site VPN** paths
- AWS **VPC + Transit Gateway + VPN** architecture
- Azure **VNet + VPN Gateway + UDR** architecture
- **Terraform** infrastructure definitions for both clouds
- **Python + Netmiko**, **Ansible**, and **pyATS/Genie** network automation
- Pre/post-change validation and configuration backup workflows
- Nine failure-scenario runbooks covering realistic routing, VPN, firewall, and cloud failures

## Architecture at a Glance

```text
                         INTERNET
                            |
                     +--------------+
                     | Palo Alto FW |
                     +------+-------+
                            |
                    +-------+-------+
                    | Enterprise    |
                    | Core          |
                    +-------+-------+
                       /         \
                  CORE-R1       CORE-R2
                  /    \         /    \
             Site1   Site2   Site3   Site4
              A10     A20     A30     A40
                 \      \     /      /
                  +------\---/------+
                         Area 0

                  Hybrid Cloud Edge
                  /                \
                 /                  \
        AWS Transit Gateway      Azure VPN Gateway
          /            \          /            \
     Prod VPC        Dev VPC  Prod VNet      Dev VNet
```

Full addressing, ASNs, security zones, routing domains, and traffic flows are documented in [`documentation/architecture.md`](documentation/architecture.md).

## Engineering Highlights

| Area | Implementation |
|---|---|
| Enterprise routing | OSPF Area 0 backbone with branch Areas 10/20/30/40 |
| Cloud routing | eBGP from enterprise AS 65000 to AWS AS 64512 and Azure AS 65515 |
| AWS resilience | Two Site-to-Site VPN connections, four IPsec tunnels total |
| Azure connectivity | Route-based VPN Gateway with BGP and separate on-prem/Azure peer addressing |
| Route control | Summarization, filtering, local preference, AS-path prepending, controlled redistribution |
| Automation | Netmiko state collection, Ansible validation, pyATS/Genie pre/post checks |
| IaC | Terraform definitions for AWS and Azure networking |
| Operations | Nine incident runbooks with symptom -> investigation -> root cause -> fix -> validation |

## Failure-Driven Troubleshooting

Instead of documenting only the healthy design, the lab includes deliberately modeled failure scenarios:

1. BGP neighbor down
2. OSPF adjacency failure
3. Wrong route advertisement
4. Route redistribution loop
5. VPN tunnel failure
6. NAT misconfiguration
7. Firewall policy denial
8. Asymmetric routing
9. Cloud route-table error

Each runbook follows an operations-oriented workflow:

```text
SYMPTOM
   ↓
INVESTIGATION
   ↓
COMMANDS / EVIDENCE
   ↓
ROOT CAUSE
   ↓
FIX
   ↓
VALIDATION
```

See [`documentation/failure-scenarios/`](documentation/failure-scenarios/).

## Automation

The automation layer is designed around repeatable network change validation.

```text
Collect state
    ↓
Backup configurations
    ↓
Apply / simulate change
    ↓
Collect post-change state
    ↓
Compare routing + interfaces + neighbors
    ↓
Generate validation report
```

Included tooling:

- **Netmiko** — configuration backup and state collection
- **Ansible** — repeatable pre/post-change workflows
- **pyATS / Genie** — structured network-state parsing and validation
- **Python** — report generation and operational utilities

Start with [`automation/README.md`](automation/README.md).

## Infrastructure as Code

Terraform defines the cloud networking layer.

```text
terraform/
├── aws/
│   ├── VPCs
│   ├── Transit Gateway
│   ├── TGW route tables
│   └── redundant Site-to-Site VPN
└── azure/
    ├── VNets
    ├── VPN Gateways
    ├── Local Network Gateways
    └── UDRs
```

### Validation performed

The Terraform configurations were formatted and validated locally:

```text
AWS
Success! The configuration is valid.

Azure
Success! The configuration is valid.
```

Additional checks performed during the upgrade:

```text
terraform fmt -recursive terraform/
python3 -m compileall -q automation
git diff --check
```

Provider lock files are committed for reproducible initialization.

## Repository Map

```text
documentation/
├── architecture.md
├── routing.md
├── cloud-networking.md
├── validation-testing.md
├── troubleshooting.md
└── failure-scenarios/

automation/
├── collect_interfaces.py
├── collect_routes.py
├── collect_ospf_neighbors.py
├── collect_bgp_neighbors.py
├── backup_configs.py
├── generate_validation_report.py
├── ansible/
└── pyats/

terraform/
├── aws/
└── azure/

scripts/
├── route-verification.sh
├── traffic-analysis.sh
└── vpn-tunnel-test.sh
```

## Explore the Project

| If you want to see... | Start here |
|---|---|
| Overall architecture | [`documentation/architecture.md`](documentation/architecture.md) |
| OSPF/BGP design | [`documentation/routing.md`](documentation/routing.md) |
| AWS + Azure networking | [`documentation/cloud-networking.md`](documentation/cloud-networking.md) |
| Troubleshooting examples | [`documentation/failure-scenarios/`](documentation/failure-scenarios/) |
| Automation | [`automation/README.md`](automation/README.md) |
| Terraform | [`terraform/README.md`](terraform/README.md) |
| Test strategy | [`documentation/validation-testing.md`](documentation/validation-testing.md) |

## Skills Demonstrated

`OSPF` · `BGP` · `Route Redistribution` · `Route Filtering` · `IPsec VPN` · `Palo Alto` · `AWS VPC` · `AWS Transit Gateway` · `Azure VNet` · `Azure VPN Gateway` · `Terraform` · `Python` · `Netmiko` · `Ansible` · `pyATS` · `Genie` · `Git`

## Validation Scope

This repository is a **simulation and infrastructure-design project**.

- Network devices are modeled as a lab environment.
- Terraform configuration has passed `terraform validate`.
- Terraform definitions are not presented as proof that cloud resources were deployed into a live production account.
- Example CLI output should be treated as expected-state or illustrative output unless specifically identified as captured lab evidence.

That distinction is intentional: the goal is to demonstrate technically defensible architecture, automation, validation, and troubleshooting without overstating what was deployed.

## Development Workflow

This upgrade was developed through a feature branch and pull request workflow:

```text
main
  ↓
feature branch
  ↓
implementation
  ↓
validation
  ↓
pull request
  ↓
technical corrections
  ↓
merge
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the repository workflow.
