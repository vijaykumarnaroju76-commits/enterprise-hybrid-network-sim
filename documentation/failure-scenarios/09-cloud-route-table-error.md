# 09 — Cloud Route-Table Error

## SYMPTOM

Azure Prod "app" subnet (172.32.1.0/24) VMs can reach the internet and each other but cannot reach anything on-premises. Azure Prod "data" subnet (172.32.2.0/24) is fine. AWS is unaffected.

## INVESTIGATION

Since only one subnet within one VNet is affected, and on-prem BGP/VPN health should be checked first to rule out a repeat of scenario 05 before assuming it's cloud-side:

```
CORE-R2# show ip bgp summary | include 169.254.20
169.254.20.1    4 65515      88      91       50    0    0 02:14:09        4
```
The Azure BGP session is Established with 4 prefixes — on-prem side is healthy. The fault is isolated to the Azure side, and specifically to routing *out of* the affected subnet, since inbound reachability to it (from on-prem, per the VNet's own perspective) isn't the complaint — outbound from that subnet is.

## COMMANDS

```bash
az network vnet route-table route list -g rg-prod --route-table-name RT-PROD-APP -o table
Name                  AddressPrefix    NextHopType
--------------------  ---------------  --------------------------
to-onprem             10.0.0.0/8       VirtualNetworkGateway

az network vnet subnet show -g rg-prod --vnet-name vnet-prod -n app --query routeTable
{
  "id": "/subscriptions/.../routeTables/RT-PROD-APP"
}

az network vnet subnet show -g rg-prod --vnet-name vnet-prod -n data --query routeTable
{
  "id": "/subscriptions/.../routeTables/RT-PROD-DATA"
}
```
Both route tables (`RT-PROD-APP`, `RT-PROD-DATA`) contain the correct UDR to `10.0.0.0/8` via the Virtual Network Gateway, matching [../cloud-networking.md](../cloud-networking.md) §2.2, and both are associated with their respective subnets. The route table itself isn't the problem — check the VPN Gateway's actual BGP-learned routes and whether the gateway is propagating them into the VNet at all for that specific path.

```bash
az network vpn-gateway list-bgp-peer-status -g rg-prod -n vgw-prod -o table
Neighbor        Asn    State        ...
10.255.0.2      65000  Connected

az network nsg rule list -g rg-prod --nsg-name nsg-prod-app -o table
Name              Priority  Direction  Access  Protocol  Source           Destination
Deny-OnPrem-Tmp   100       Inbound    Deny    *         10.0.0.0/8       *
Allow-VNet        200       Inbound    Allow   *         VirtualNetwork   *
```
Found it: an NSG rule (`Deny-OnPrem-Tmp`) on the `app` subnet's NSG, priority 100 (evaluated before the `Allow-VNet` rule at 200), denying all inbound traffic from `10.0.0.0/8`. Routing was never broken — the UDR and BGP path are both correct — this is a security-group-layer denial that looks identical to a routing failure from the affected VM's perspective (connections simply don't arrive), which is exactly why it's filed under "cloud route-table error" investigation even though the root cause turned out one layer up.

## ROOT CAUSE

`Deny-OnPrem-Tmp` was added during an incident response drill to temporarily block on-prem-sourced traffic to the app subnet while investigating unrelated suspicious activity, with a plan to remove it once the drill concluded — the removal step was never done. Because it's evaluated at priority 100 (lower number = higher priority in Azure NSGs) ahead of the standard `Allow-VNet`/allow rules, it silently blocks all legitimate on-prem-to-app traffic while leaving VNet-internal and internet-bound traffic (matched by other rules) completely unaffected, which is why only the on-prem path looked broken.

## FIX

```bash
az network nsg rule delete -g rg-prod --nsg-name nsg-prod-app -n Deny-OnPrem-Tmp
```

## VALIDATION

```bash
az network nsg rule list -g rg-prod --nsg-name nsg-prod-app -o table
Name         Priority  Direction  Access  Protocol  Source           Destination
Allow-VNet   200       Inbound    Allow   *         VirtualNetwork   *
```
```
# from an on-prem host
ping 172.32.1.10
Success rate is 100 percent (5/5)
```
On-prem-to-app connectivity is restored. Since this NSG rule masqueraded as a routing fault, also run the automation validation report's route-table cross-check (see [`../../automation/`](../../automation/)) against every subnet's NSG, not just its UDR, so a similar temporary rule left behind on `data` or on the Dev VNet doesn't surface the same way later. As a process fix, incident-response runbooks that add temporary NSG/firewall rules should include an expiry ticket or scheduled removal, not rely on someone remembering.
