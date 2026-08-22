# Cloud Networking: On-Prem -> AWS + Azure

This document extends the on-premises design in [architecture.md](architecture.md) and [routing.md](routing.md) into AWS and Azure. Terraform under [`terraform/`](../terraform/) is the infrastructure definition. Unless explicitly stated otherwise, addresses and command outputs here are design/expected-state values rather than proof of a live deployment.

## 1. AWS

```text
CORE-R1 (primary) -- Site-to-Site VPN (2 tunnels) --+
                                                     +-- Transit Gateway (AS 64512)
CORE-R2 (backup)  -- Site-to-Site VPN (2 tunnels) --+
                                                     +-- Prod VPC 172.31.0.0/16
                                                     +-- Dev VPC  172.30.0.0/16
```

### 1.1 VPCs and subnets

| VPC | CIDR | Subnet | CIDR | Purpose |
|---|---|---|---|---|
| Prod | 172.31.0.0/16 | TGW attach | 172.31.0.0/24 | TGW attachment |
| Prod | 172.31.0.0/16 | App | 172.31.1.0/24 | Application tier |
| Prod | 172.31.0.0/16 | Data | 172.31.2.0/24 | Data tier |
| Dev | 172.30.0.0/16 | TGW attach | 172.30.0.0/24 | TGW attachment |
| Dev | 172.30.0.0/16 | App | 172.30.1.0/24 | Development tier |

### 1.2 Transit Gateway route isolation

Prod and Dev use separate TGW route tables. Each VPC is associated only with its corresponding route table. Both VPN attachments may propagate the on-premises `10.0.0.0/8` aggregate into both tables, while the Prod and Dev VPC CIDRs are kept in their respective tables.

```text
TGW-RT-PROD
  10.0.0.0/8    -> propagated from VPN attachments
  172.31.0.0/16 -> Prod VPC attachment

TGW-RT-DEV
  10.0.0.0/8    -> propagated from VPN attachments
  172.30.0.0/16 -> Dev VPC attachment
```

### 1.3 Site-to-Site VPN and BGP

AWS Site-to-Site VPN creates two tunnels per VPN connection. The Terraform design therefore creates four AWS tunnels in total:

| Connection | Role | Tunnel | Inside CIDR |
|---|---|---|---|
| CORE-R1 <-> TGW | Primary | 1 | 169.254.10.0/30 |
| CORE-R1 <-> TGW | Primary | 2 | 169.254.10.4/30 |
| CORE-R2 <-> TGW | Backup | 1 | 169.254.10.8/30 |
| CORE-R2 <-> TGW | Backup | 2 | 169.254.10.12/30 |

- Enterprise ASN: `65000`
- AWS TGW ASN: `64512`
- Dynamic routing: BGP (`static_routes_only = false`)
- Tunnel inside CIDRs are explicitly set in Terraform so the infrastructure definition and documentation stay deterministic.
- The exact customer-side and AWS-side usable IP assigned within each `/30` must be taken from the resulting AWS VPN configuration/Terraform outputs when configuring the routers; this document does not invent those host addresses.
- Both VPN attachments propagate on-prem routes into the Prod and Dev TGW route tables.

### 1.4 AWS security

Security Groups provide stateful workload filtering. NACLs may provide subnet-level controls. VPC Flow Logs can be enabled for operational visibility. These controls are design recommendations unless their corresponding Terraform resources exist in this repository.

## 2. Azure

This lab intentionally uses one VPN Gateway per VNet instead of Azure Virtual WAN.

```text
CORE-R2 -- primary --> Azure Prod VPN Gateway --> Prod VNet 172.32.0.0/16
CORE-R1 -- backup  --> Azure Prod VPN Gateway

CORE-R2 -- primary --> Azure Dev VPN Gateway  --> Dev VNet  172.33.0.0/16
```

### 2.1 VNets and subnets

| VNet | CIDR | Subnet | CIDR | Purpose |
|---|---|---|---|---|
| Prod | 172.32.0.0/16 | GatewaySubnet | 172.32.0.0/27 | VPN Gateway |
| Prod | 172.32.0.0/16 | App | 172.32.1.0/24 | Application tier |
| Prod | 172.32.0.0/16 | Data | 172.32.2.0/24 | Data tier |
| Dev | 172.33.0.0/16 | GatewaySubnet | 172.33.0.0/27 | VPN Gateway |
| Dev | 172.33.0.0/16 | App | 172.33.1.0/24 | Development tier |

### 2.2 User-defined routes

Workload subnets that require on-premises connectivity use a UDR for `10.0.0.0/8` with next hop type `Virtual network gateway`. `GatewaySubnet` is left on Azure system routing.

### 2.3 VPN Gateway and BGP

Azure and the on-premises routers use distinct BGP peering addresses.

| Connection | On-prem peer | Azure VNG peer | ASN pair |
|---|---|---|---|
| CORE-R2 -> Prod primary | 169.254.20.1 | 169.254.20.2 | 65000 / 65515 |
| CORE-R1 -> Prod backup | 169.254.20.5 | See note below | 65000 / 65515 |
| CORE-R2 -> Dev primary | 169.254.21.1 | 169.254.21.2 | 65000 / 65515 |

The Terraform Local Network Gateway `bgp_peering_address` represents the **on-premises** BGP speaker. The Azure Virtual Network Gateway has its own BGP peer address. These must never be represented as the same endpoint.

**Prod backup note:** the current single-instance Prod VNG Terraform defines one custom Azure APIPA address (`169.254.20.2`). Before a real deployment, validate Azure's supported custom APIPA pairing for multiple on-prem connections and adjust the backup peer definition if Azure requires a distinct VNG APIPA address for that connection. This repository does not claim that this backup pairing has been live-tested.

### 2.4 Azure security

NSGs should restrict workload traffic according to application requirements. Azure network-flow telemetry can be enabled separately. The repository should only claim a control is deployed when a corresponding configuration/resource actually exists.

## 3. Cross-cloud traffic

There is no native AWS-to-Azure link in this lab. Any cross-cloud path must intentionally transit the on-premises hub:

```text
AWS workload
 -> AWS TGW
 -> AWS VPN
 -> CORE-R1/CORE-R2
 -> Azure VPN
 -> Azure workload
```

Do not infer AWS-to-Azure route exchange from illustrative BGP output. AWS outbound and Azure outbound routing policies are intended to advertise the enterprise aggregate, not turn either cloud into transit for the other.

## 4. Validation

These commands are examples of what should be checked after infrastructure is actually provisioned.

```bash
# AWS
aws ec2 describe-vpn-connections --query 'VpnConnections[].VgwTelemetry'
aws ec2 describe-transit-gateway-route-tables

# Azure
az network vpn-connection show -g <rg> -n <conn-name> --query connectionStatus
az network vpn-gateway list-bgp-peer-status -g <rg> -n <vpn-gw-name>
```

On the routers, validate BGP sessions, learned prefixes, next hops, and failover using the commands in [routing.md](routing.md).

## 5. Validation status

Terraform in this repository defines the intended infrastructure but has not been claimed as applied to a live AWS/Azure account. Example `show` and cloud CLI outputs should be treated as illustrative/expected state unless explicitly labeled as captured from a running lab.
