# Architecture

This document is the source of truth for the simulation's topology, addressing, VLANs, routing domains, security zones, and traffic flows. Every other document (routing, cloud networking, failure scenarios, automation, Terraform) references the numbering defined here — if you change an address or ASN, update it here first.

## 1. Topology

```
                                   INTERNET
                                       |
                               ┌───────┴────────┐
                               │  Palo Alto FW   │  (untrust <-> DMZ <-> trust)
                               │   PA-EDGE-01    │
                               └───────┬────────┘
                                       |
                             ┌─────────┴─────────┐
                             │  Enterprise Core   │  (L3 switching, VLAN SVIs)
                             │  CORE-SW-01/02     │
                             └────┬─────────┬────┘
                                  |         |
                              ┌───┴───┐ ┌───┴───┐
                              │ CORE  │ │ CORE  │
                              │  R1   │ │  R2   │   iBGP + OSPF Area 0
                              └───┬───┘ └───┬───┘   (dual-homed border pair)
                       ┌──────────┤         ├──────────┐
                       |          |         |          |
                  ┌────┴───┐  ┌───┴────┐┌───┴────┐ ┌───┴────┐
                  │ SITE1  │  │ SITE2  ││ SITE3  │ │ SITE4  │   OSPF Area 10
                  │ RTR    │  │ RTR    ││ RTR    │ │ RTR    │   (branch sites)
                  └────────┘  └────────┘└────────┘ └────────┘
                                  |         |
                            eBGP  |         |  eBGP
                        (primary) |         | (primary)
                                  |         |
                            ┌─────┴───┐ ┌───┴─────┐
                            │   AWS   │ │  Azure  │
                            │  (R1)   │ │  (R2)   │   cross-links = backup paths
                            └────┬────┘ └────┬────┘   R1<->Azure, R2<->AWS (dashed)
                                 |            |
                       ┌─────────┴───────┐ ┌──┴──────────────┐
                       │ Transit Gateway │ │  VPN Gateway     │
                       │   AS 64512      │ │  AS 65515        │
                       └───┬─────────┬───┘ └───┬──────────┬──┘
                           |         |          |          |
                     ┌─────┴──┐ ┌────┴───┐┌─────┴──┐ ┌─────┴──┐
                     │Prod VPC│ │Dev VPC ││Prod VNet│ │Dev VNet│
                     │172.31/16│ │172.30/16││172.32/16│ │172.33/16│
                     └────────┘ └────────┘└────────┘ └────────┘
```

Redundancy model: **CORE-R1** is the primary on-premises peer for AWS and the backup peer for Azure; **CORE-R2** is the primary peer for Azure and the backup peer for AWS. Both links per cloud are always up — BGP local preference and AS-path prepending (see [routing.md](routing.md)) decide which one carries production traffic, so a single router or single VPN tunnel failure never isolates a cloud.

## 2. Autonomous System / Router ID Plan

| Entity | ASN | Router ID / Loopback (Lo0) | Role |
|---|---|---|---|
| Enterprise (on-prem) | 65000 | — | Private ASN, iBGP between CORE-R1/R2, redistributes into OSPF |
| CORE-R1 | 65000 | 10.255.0.1 | Border router, primary AWS peer |
| CORE-R2 | 65000 | 10.255.0.2 | Border router, primary Azure peer |
| SITE1-RTR | 65000 (OSPF only, no eBGP) | 10.255.0.11 | Branch, Area 10 |
| SITE2-RTR | 65000 | 10.255.0.12 | Branch, Area 10 |
| SITE3-RTR | 65000 | 10.255.0.13 | Branch, Area 10 |
| SITE4-RTR | 65000 | 10.255.0.14 | Branch, Area 10 |
| AWS Transit Gateway | 64512 | — | Cloud edge, AWS-managed |
| Azure VPN Gateway | 65515 | — | Cloud edge, Azure default BGP ASN |

Loopbacks are carved from `10.255.0.0/24`, used as OSPF router IDs and BGP `update-source`/`next-hop-self` anchors so adjacencies survive a single physical-interface flap.

## 3. IP Addressing Plan

### 3.1 On-premises site networks

| Site | Aggregate | Users | Servers | Management |
|---|---|---|---|---|
| HQ (Core) | 10.0.0.0/16 | 10.0.10.0/24 | 10.0.20.0/24 | 10.0.99.0/24 |
| Site1 | 10.1.0.0/16 | 10.1.1.0/24 | 10.1.2.0/24 | 10.1.99.0/24 |
| Site2 | 10.2.0.0/16 | 10.2.1.0/24 | 10.2.2.0/24 | 10.2.99.0/24 |
| Site3 | 10.3.0.0/16 | 10.3.1.0/24 | 10.3.2.0/24 | 10.3.99.0/24 |
| Site4 | 10.4.0.0/16 | 10.4.1.0/24 | 10.4.2.0/24 | 10.4.99.0/24 |

The whole on-prem block summarizes to `10.0.0.0/8` and is advertised to the clouds as a single aggregate (`aggregate-address 10.0.0.0 255.0.0.0 summary-only`) to keep the cloud-side route tables small.

### 3.2 WAN transit links (Core <-> Site routers, point-to-point /30s)

| Link | Subnet |
|---|---|
| CORE-R1 <-> SITE1-RTR | 192.168.1.0/30 |
| CORE-R1 <-> SITE2-RTR | 192.168.1.4/30 |
| CORE-R2 <-> SITE3-RTR | 192.168.1.8/30 |
| CORE-R2 <-> SITE4-RTR | 192.168.1.12/30 |
| CORE-R1 <-> CORE-R2 (iBGP/OSPF backbone link) | 192.168.1.16/30 |

### 3.3 VPN transport (on-prem to cloud)

| Tunnel | Local | Remote (cloud endpoint) |
|---|---|---|
| CORE-R1 -> AWS TGW (primary) | Tunnel0, 169.254.10.0/30 | 203.0.113.1 |
| CORE-R2 -> AWS TGW (backup) | Tunnel1, 169.254.10.4/30 | 203.0.113.2 |
| CORE-R2 -> Azure VPN GW (primary) | Tunnel2, 169.254.20.0/30 | 203.0.113.10 |
| CORE-R1 -> Azure VPN GW (backup) | Tunnel3, 169.254.20.4/30 | 203.0.113.11 |

Tunnel interfaces use link-local `169.254.0.0/16` addressing (matching AWS/Azure VPN defaults) with MTU 1436 to absorb IPsec/GRE overhead — see [cloud-networking.md](cloud-networking.md) for the full tunnel and BGP-over-VPN configuration.

### 3.4 Cloud address space

| Cloud | VPC/VNet | CIDR | Purpose |
|---|---|---|---|
| AWS | Prod VPC | 172.31.0.0/16 | Production workloads |
| AWS | Dev VPC | 172.30.0.0/16 | Development/test |
| Azure | Prod VNet | 172.32.0.0/16 | Production workloads |
| Azure | Dev VNet | 172.33.0.0/16 | Development/test |

Full subnet breakdown (TGW/GatewaySubnet, app, data tiers) is in [cloud-networking.md](cloud-networking.md).

## 4. VLANs (HQ Core)

| VLAN | Name | Subnet | SVI (on CORE-SW) |
|---|---|---|---|
| 10 | Users | 10.0.10.0/24 | 10.0.10.1 |
| 20 | Servers | 10.0.20.0/24 | 10.0.20.1 |
| 30 | Voice | 10.0.30.0/24 | 10.0.30.1 |
| 99 | Management (OOB) | 10.0.99.0/24 | 10.0.99.1 |
| 100 | DMZ | 10.0.100.0/24 | 10.0.100.1 |

Branch sites (Site1-4) mirror VLANs 10/20/99 locally within their own `/16`, per the table in 3.1.

## 5. Routing Domains

| Domain | Protocol | Scope |
|---|---|---|
| Backbone | OSPF Area 0 | CORE-R1, CORE-R2, WAN transit link between them |
| Branches | OSPF Area 10 | SITE1-4 <-> CORE-R1/R2, injected into Area 0 via ABR |
| Enterprise <-> Cloud | eBGP | CORE-R1/R2 <-> AWS TGW (AS 64512), CORE-R2/R1 <-> Azure VPN GW (AS 65515) |
| Core redundancy | iBGP | CORE-R1 <-> CORE-R2, AS 65000, carries cloud-learned routes between border routers |

OSPF routes are redistributed into BGP (as the aggregate `10.0.0.0/8`, not individual /24s) and cloud-learned BGP routes are redistributed back into OSPF as external (E2) routes at the core so branch sites can reach AWS/Azure without running BGP themselves. See [routing.md](routing.md) for the exact redistribution and filtering configuration — this boundary is also where Upgrade 4's "route redistribution loop" failure scenario is set.

## 6. Security Zones

| Zone | Members | Trust level |
|---|---|---|
| Untrust | Internet-facing interface on PA-EDGE-01 | None |
| DMZ | VLAN 100 (10.0.100.0/24) | Restricted, published services only |
| Trust (Enterprise Core) | VLAN 10/20/30, Core routers | Internal |
| Branch | Site1-4 VLANs | Internal, policy-matched to Trust |
| Cloud-Prod | AWS Prod VPC, Azure Prod VNet | Internal, production data |
| Cloud-Dev | AWS Dev VPC, Azure Dev VNet | Internal, non-production |
| Management/OOB | VLAN 99 per site | Restricted, admin access only |

The Palo Alto firewall enforces zone-based policy at the perimeter (Untrust/DMZ/Trust). Prod and Dev cloud zones are kept on separate VPCs/VNets and separate Transit Gateway / route-table associations specifically so a Dev misconfiguration (see Upgrade 4, cloud route-table error) cannot leak into Prod.

## 7. Traffic Flows

**User to Internet (egress):** Branch/HQ VLAN -> Site or Core router (OSPF) -> CORE Core switch -> PA-EDGE-01 (NAT + security policy) -> Internet.

**Branch to HQ server:** Site VLAN -> SITE-RTR -> OSPF Area 10 -> ABR (CORE-R1/R2) -> Area 0 -> VLAN 20 SVI on CORE-SW.

**On-prem to AWS Prod:** HQ/Branch subnet -> Core (OSPF) -> CORE-R1 (eBGP, primary tunnel) -> AWS TGW -> TGW route table (prod) -> Prod VPC. On CORE-R1 failure, iBGP + lower-preference path via CORE-R2's backup tunnel takes over.

**On-prem to Azure Prod:** mirrors the AWS flow via CORE-R2 as primary, CORE-R1 as backup.

**AWS to Azure (cross-cloud):** not directly peered in this design — traffic transits on-premises (AWS -> TGW -> VPN -> CORE-R1/R2 -> CORE-R2/R1 -> VPN -> Azure VNG). This is a deliberate simplification (no cloud-to-cloud VPN or cloud WAN) that keeps on-prem as the hybrid hub, and is called out explicitly so it isn't mistaken for an oversight.

**Dev isolation:** Dev VPC/VNet route tables and UDRs only contain routes to the on-prem aggregate and to each other's Dev network — never to Prod CIDRs — enforced at the TGW route table and Azure UDR layer, not just security groups/NSGs.
