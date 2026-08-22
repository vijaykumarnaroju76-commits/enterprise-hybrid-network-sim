# Architecture

This document is the source of truth for the simulation's topology, addressing, VLANs, routing domains, security zones, and traffic flows. Every other document (routing, cloud networking, failure scenarios, automation, Terraform) should reuse the values defined here.

## 1. Topology

```text
                                   INTERNET
                                       |
                               +-------+--------+
                               |  Palo Alto FW  |
                               |   PA-EDGE-01   |
                               +-------+--------+
                                       |
                              Enterprise Core
                                  /       \
                             CORE-R1     CORE-R2
                               |           |
                          AWS primary   Azure primary
                               |           |
                              AWS        Azure
```

CORE-R1 and CORE-R2 form the redundant enterprise border pair. CORE-R1 is the preferred AWS edge and CORE-R2 is the preferred Azure edge. Backup VPN connectivity is maintained where explicitly modeled below.

## 2. Autonomous System / Router ID Plan

| Entity | ASN | Router ID / Loopback | Role |
|---|---:|---|---|
| Enterprise | 65000 | — | Private enterprise ASN |
| CORE-R1 | 65000 | 10.255.0.1 | Border router, primary AWS |
| CORE-R2 | 65000 | 10.255.0.2 | Border router, primary Azure |
| SITE1-RTR | — | 10.255.0.11 | OSPF Area 10 |
| SITE2-RTR | — | 10.255.0.12 | OSPF Area 20 |
| SITE3-RTR | — | 10.255.0.13 | OSPF Area 30 |
| SITE4-RTR | — | 10.255.0.14 | OSPF Area 40 |
| AWS Transit Gateway | 64512 | — | AWS-managed BGP peer |
| Azure VPN Gateway | 65515 | — | Azure BGP peer |

## 3. IP Addressing Plan

### 3.1 On-premises networks

| Site | Aggregate | Users | Servers | Management |
|---|---|---|---|---|
| HQ | 10.0.0.0/16 | 10.0.10.0/24 | 10.0.20.0/24 | 10.0.99.0/24 |
| Site1 | 10.1.0.0/16 | 10.1.1.0/24 | 10.1.2.0/24 | 10.1.99.0/24 |
| Site2 | 10.2.0.0/16 | 10.2.1.0/24 | 10.2.2.0/24 | 10.2.99.0/24 |
| Site3 | 10.3.0.0/16 | 10.3.1.0/24 | 10.3.2.0/24 | 10.3.99.0/24 |
| Site4 | 10.4.0.0/16 | 10.4.1.0/24 | 10.4.2.0/24 | 10.4.99.0/24 |

The enterprise advertises `10.0.0.0/8` toward the cloud. A high-administrative-distance Null0 route supplies the exact aggregate required by the BGP `network` statement while more-specific OSPF routes remain preferred.

### 3.2 WAN transit links

| Link | Subnet |
|---|---|
| CORE-R1 <-> SITE1-RTR | 192.168.1.0/30 |
| CORE-R1 <-> SITE2-RTR | 192.168.1.4/30 |
| CORE-R2 <-> SITE3-RTR | 192.168.1.8/30 |
| CORE-R2 <-> SITE4-RTR | 192.168.1.12/30 |
| CORE-R1 <-> CORE-R2 | 192.168.1.16/30 |

### 3.3 AWS Site-to-Site VPN inside networks

Each AWS Site-to-Site VPN connection contains two AWS-managed IPsec tunnels. The Terraform configuration assigns deterministic inside CIDRs:

| Connection | Tunnel | Inside CIDR |
|---|---|---|
| CORE-R1 primary AWS VPN | Tunnel 1 | 169.254.10.0/30 |
| CORE-R1 primary AWS VPN | Tunnel 2 | 169.254.10.4/30 |
| CORE-R2 backup AWS VPN | Tunnel 1 | 169.254.10.8/30 |
| CORE-R2 backup AWS VPN | Tunnel 2 | 169.254.10.12/30 |

The actual customer-gateway and AWS-side usable addresses within each /30 must match the values returned by AWS for the VPN connection and should be consumed from Terraform/AWS outputs when building the router configuration.

### 3.4 Azure BGP peering

Azure and on-premises BGP peers use distinct APIPA addresses.

| Connection | On-prem BGP peer | Azure VNG BGP peer |
|---|---|---|
| CORE-R2 -> Azure Prod (primary) | 169.254.20.1 | 169.254.20.2 |
| CORE-R1 -> Azure Prod (backup) | 169.254.20.5 | Azure peer address must be configured consistently for the backup connection |
| CORE-R2 -> Azure Dev (primary) | 169.254.21.1 | 169.254.21.2 |

The Terraform configuration explicitly defines custom APIPA addresses for the Azure virtual network gateways where modeled. On-premises Local Network Gateway `bgp_peering_address` values represent the customer-side peer, not the Azure-side neighbor.

### 3.5 Cloud address space

| Cloud | Network | CIDR |
|---|---|---|
| AWS | Prod VPC | 172.31.0.0/16 |
| AWS | Dev VPC | 172.30.0.0/16 |
| Azure | Prod VNet | 172.32.0.0/16 |
| Azure | Dev VNet | 172.33.0.0/16 |

## 4. VLANs

| VLAN | Name | HQ Subnet |
|---|---|---|
| 10 | Users | 10.0.10.0/24 |
| 20 | Servers | 10.0.20.0/24 |
| 30 | Voice | 10.0.30.0/24 |
| 99 | Management | 10.0.99.0/24 |
| 100 | DMZ | 10.0.100.0/24 |

LAN interfaces are passive in OSPF. Their prefixes are advertised, but endpoints are not expected to form routing adjacencies.

## 5. Routing Domains

| Domain | Protocol | Scope |
|---|---|---|
| Backbone | OSPF Area 0 | CORE-R1 <-> CORE-R2 |
| Site1 | OSPF Area 10 | SITE1-RTR <-> CORE-R1 |
| Site2 | OSPF Area 20 | SITE2-RTR <-> CORE-R1 |
| Site3 | OSPF Area 30 | SITE3-RTR <-> CORE-R2 |
| Site4 | OSPF Area 40 | SITE4-RTR <-> CORE-R2 |
| Enterprise <-> AWS | eBGP | AS 65000 <-> AS 64512 |
| Enterprise <-> Azure | eBGP | AS 65000 <-> AS 65515 |
| Core redundancy | iBGP | CORE-R1 <-> CORE-R2 |

Cloud-learned routes can be redistributed into OSPF under explicit prefix filtering. Enterprise routes are not blindly redistributed into BGP; only the intentional `10.0.0.0/8` aggregate is originated.

## 6. Security Zones

| Zone | Purpose |
|---|---|
| Untrust | Internet-facing |
| DMZ | Published services |
| Trust | Enterprise internal networks |
| Branch | Branch-site networks |
| Cloud-Prod | Production cloud workloads |
| Cloud-Dev | Development cloud workloads |
| Management/OOB | Administrative access |

## 7. Traffic Flows

**Internet egress:** Enterprise/branch -> core -> Palo Alto -> Internet.

**Branch to HQ:** Branch LAN -> site router -> OSPF -> core -> HQ server VLAN.

**On-prem to AWS:** Enterprise route -> preferred CORE-R1 AWS VPN; CORE-R2 provides the backup AWS VPN connection.

**On-prem to Azure Prod:** Enterprise route -> CORE-R2 primary Azure connection. CORE-R1 provides the documented Prod backup connection.

**On-prem to Azure Dev:** Enterprise route -> CORE-R2 -> Azure Dev VNG.

**AWS to Azure:** There is no native direct AWS-to-Azure peering in this lab. Any cross-cloud routing must be explicitly engineered through the on-premises hub and must not be inferred from illustrative BGP output.

## 8. Validation Status

The configuration snippets and command outputs in this repository are design/expected-state examples unless explicitly labeled as captured lab output. Terraform represents deployable infrastructure definitions, but this repository does not claim that the AWS/Azure resources have been applied to a live account.

Before treating the design as validated, run Terraform formatting/validation, Python syntax checks, YAML parsing, and the documented GNS3/network validation procedures.
