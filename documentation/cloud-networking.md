# Cloud Networking: On-Prem → AWS → Azure

Extends the on-prem design in [architecture.md](architecture.md) and [routing.md](routing.md) into both public clouds. Terraform that provisions the resources described here lives in [`terraform/`](../terraform/); this document is the design record, Terraform is the implementation.

## 1. AWS

```
CORE-R1 (primary) ---VPN(BGP AS64512)--- Transit Gateway ---+--- TGW-RT-PROD ---+--- Prod VPC (172.31.0.0/16)
CORE-R2 (backup)  ---VPN(BGP AS64512)---/                   |                    |     subnets: TGW-attach .0/24, App .1.0/24, Data .2.0/24
                                                              +--- TGW-RT-DEV  ----+--- Dev VPC (172.30.0.0/16)
                                                                                          subnets: TGW-attach .0/24, App .1.0/24
```

### 1.1 VPCs and subnets

| VPC | CIDR | Subnet | CIDR | Purpose |
|---|---|---|---|---|
| Prod VPC | 172.31.0.0/16 | tgw-attach | 172.31.0.0/24 | TGW ENI attachment |
| Prod VPC | 172.31.0.0/16 | app | 172.31.1.0/24 | Application tier |
| Prod VPC | 172.31.0.0/16 | data | 172.31.2.0/24 | Database tier |
| Dev VPC | 172.30.0.0/16 | tgw-attach | 172.30.0.0/24 | TGW ENI attachment |
| Dev VPC | 172.30.0.0/16 | app | 172.30.1.0/24 | Application tier |

### 1.2 Route tables

Each VPC has its own route table pointing default-internal traffic at the TGW attachment; the TGW itself has **two separate route tables** (`TGW-RT-PROD`, `TGW-RT-DEV`) so a route leak between Prod and Dev is architecturally impossible, not just a security-group policy:

```
# Prod VPC route table
10.0.0.0/8       -> tgw-attachment (on-prem, via TGW-RT-PROD)
172.30.0.0/16    -> (no route — Dev is not present in this table)
local            -> local

# Dev VPC route table
10.0.0.0/8       -> tgw-attachment (on-prem, via TGW-RT-DEV)
172.31.0.0/16    -> (no route — Prod is not present in this table)
local            -> local
```

```
# TGW-RT-PROD associations: Prod VPC attachment, VPN attachment (propagated)
#   propagated routes from on-prem VPN: 10.0.0.0/8
#   static: 172.31.0.0/16 -> Prod VPC attachment

# TGW-RT-DEV associations: Dev VPC attachment, VPN attachment (propagated)
#   propagated routes from on-prem VPN: 10.0.0.0/8
#   static: 172.30.0.0/16 -> Dev VPC attachment
```

### 1.3 Transit Gateway + Site-to-Site VPN

- TGW ASN: `64512` (matches `routing.md` BGP config)
- Two VPN connections, each with two tunnels (AWS always provisions tunnel pairs for HA):
  - **VPN-1** (primary): customer gateway = CORE-R1 public IP, outside tunnel endpoints `203.0.113.1` / `203.0.113.2`
  - **VPN-2** (backup): customer gateway = CORE-R2 public IP, used as the AWS-side backup path from `routing.md`
- Route propagation is **enabled** from both VPN attachments into `TGW-RT-PROD` and `TGW-RT-DEV` — this is the AWS-console setting most commonly missed, and its absence is exactly [failure-scenarios/09-cloud-route-table-error.md](failure-scenarios/09-cloud-route-table-error.md).

### 1.4 Security controls

- Security Groups scope traffic within a VPC (stateful, tier-to-tier: app -> data only on the application port).
- NACLs on the tgw-attach subnets restrict inbound to the on-prem aggregate `10.0.0.0/8` only.
- VPC Flow Logs enabled on both VPCs, shipped to CloudWatch Logs for the automation reporting pipeline in [`automation/`](../automation/).

## 2. Azure

```
CORE-R2 (primary) ---VPN(BGP AS65515)--- VPN Gateway ---+--- Prod VNet (172.32.0.0/16) --- UDR: 10.0.0.0/8 -> VPN GW
CORE-R1 (backup)  ---VPN(BGP AS65515)---/               |
                                                          +--- Dev VNet (172.33.0.0/16) --- UDR: 10.0.0.0/8 -> VPN GW
```

### 2.1 VNets and subnets

| VNet | CIDR | Subnet | CIDR | Purpose |
|---|---|---|---|---|
| Prod VNet | 172.32.0.0/16 | GatewaySubnet | 172.32.0.0/27 | VPN Gateway (name is fixed by Azure) |
| Prod VNet | 172.32.0.0/16 | app | 172.32.1.0/24 | Application tier |
| Prod VNet | 172.32.0.0/16 | data | 172.32.2.0/24 | Database tier |
| Dev VNet | 172.33.0.0/16 | GatewaySubnet | 172.33.0.0/27 | VPN Gateway |
| Dev VNet | 172.33.0.0/16 | app | 172.33.1.0/24 | Application tier |

Unlike AWS's Transit Gateway model, each VNet in this design gets its **own** VPN Gateway rather than a shared hub — this is a deliberate architectural difference called out here so it isn't mistaken for asymmetry/inconsistency: Azure Virtual WAN (a TGW equivalent) is a documented future enhancement, not implemented in this stage.

### 2.2 User-Defined Routes (UDR)

Azure's default system routes only know about the local VNet, so every subnet that needs on-prem reachability gets a route table associated with a UDR:

```
# UDR: RT-PROD-APP (associated to Prod VNet "app" subnet)
Address prefix: 10.0.0.0/8
Next hop type:  Virtual network gateway

# UDR: RT-PROD-DATA (associated to Prod VNet "data" subnet)
Address prefix: 10.0.0.0/8
Next hop type:  Virtual network gateway

# UDR: RT-DEV-APP (associated to Dev VNet "app" subnet)
Address prefix: 10.0.0.0/8
Next hop type:  Virtual network gateway
```

`GatewaySubnet` never gets a custom UDR — Azure requires it stay on system routes, and attaching one is the single most common cause of an Azure VPN Gateway losing on-prem reachability. See [failure-scenarios/09-cloud-route-table-error.md](failure-scenarios/09-cloud-route-table-error.md) for that exact failure walked through end to end.

### 2.3 VPN Gateway + BGP

- SKU: `VpnGw2` (route-based, active-active not required since redundancy comes from the dual on-prem core routers rather than dual Azure gateway instances)
- BGP ASN: `65515` (Azure's default gateway ASN — using the default instead of a custom one because Azure reserves `65515–65520` for its own use, so a custom ASN in that range is rejected and picking one outside it gains nothing here)
- Two connections mirroring the AWS pattern: primary from CORE-R2 (`203.0.113.10`), backup from CORE-R1 (`203.0.113.11`)
- Local network gateways define `10.0.0.0/8` as the on-prem address space (must match the aggregate CORE-R1/R2 actually advertise, or BGP-learned routes and the static local-network-gateway prefix silently disagree)

### 2.4 Security controls

- NSGs on `app`/`data` subnets, same tier-to-tier model as AWS Security Groups.
- Azure Firewall or NSG rule restricts `GatewaySubnet` inbound to the on-prem aggregate only.
- NSG Flow Logs + Traffic Analytics enabled on Prod and Dev VNets.

## 3. End-to-End Path: On-Prem → AWS → Azure

There is no direct AWS-to-Azure link in this design (see architecture.md §7). A packet from an AWS Prod EC2 instance to an Azure Prod VM takes:

```
AWS Prod VPC (172.31.1.0/24)
  -> TGW-RT-PROD -> VPN-1 -> CORE-R1
  -> iBGP/OSPF -> CORE-R2
  -> VPN (Azure primary) -> Azure VPN Gateway
  -> UDR on Prod VNet app subnet -> Azure Prod VM (172.32.1.0/24)
```

Both hops (AWS side and Azure side) are independently redundant per §1.3/§2.3, but the on-prem core is a single logical hop in the middle — a full core outage (both CORE-R1 and CORE-R2 down) is the one scenario this design cannot route around, which is an accepted trade-off for keeping on-prem as the hybrid hub instead of adding cloud-to-cloud peering.

## 4. Validation Commands (cloud side)

```bash
# AWS
aws ec2 describe-vpn-connections --query 'VpnConnections[].VgwTelemetry'
aws ec2 describe-transit-gateway-route-tables
aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id <id> \
  --filters Name=state,Values=active

# Azure
az network vpn-connection show -g <rg> -n <conn-name> --query connectionStatus
az network vnet route-table route list -g <rg> --route-table-name RT-PROD-APP
az network vpn-gateway list-bgp-peer-status -g <rg> -n <vpn-gw-name>
```

These map directly to the on-prem `show ip bgp summary` / `show ip route` output in [routing.md](routing.md#6-verification-commands-and-expected-output) — a healthy hybrid path requires both sides to agree, which is exactly what the [`automation/`](../automation/) collection scripts and the Terraform outputs in [`terraform/`](../terraform/) are set up to cross-check.
