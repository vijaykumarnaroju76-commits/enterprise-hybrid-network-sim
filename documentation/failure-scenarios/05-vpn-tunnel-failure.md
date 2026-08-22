# 05 — VPN Tunnel Failure

## SYMPTOM

Azure Prod connectivity from HQ is down. AWS and Azure Dev are unaffected. Azure portal shows the primary connection (CORE-R2) status as "Not Connected".

```
CORE-R2# show ip bgp summary | include 169.254.20
169.254.20.1    4 65515       0       0        1    0    0 00:03:11 Active

CORE-R2# show interface tunnel2
Tunnel2 is up, line protocol is down
```
Line protocol down on an "up" tunnel interface means the tunnel's keepalive/encapsulation isn't completing even though the interface is administratively enabled — check IKE/IPsec state directly.

## INVESTIGATION

```
CORE-R2# show crypto ikev2 sa
IPv4 Crypto IKEv2  SA
                                     (no entries)

CORE-R2# show crypto session
There are no active sessions.
```
No IKEv2 SA at all — Phase 1 (IKE) never established, so nothing downstream (Phase 2, BGP over the tunnel) had a chance to.

## COMMANDS

```
CORE-R2# ping 203.0.113.10
Success rate is 0 percent (0/5)

CORE-R2# show ip route 203.0.113.10
% Network not in table

CORE-R2# show run | section crypto ikev2 profile
crypto ikev2 profile AZURE-PRIMARY
 match identity remote address 203.0.113.10 255.255.255.255
 authentication local pre-share
 authentication remote pre-share
 keyring local AZURE-KEYRING
```
The Azure VPN Gateway's public IP (`203.0.113.10`, per [../architecture.md](../architecture.md) §3.3) is unreachable from CORE-R2 at all — not an IKE negotiation failure, an IP-layer failure underneath it. Check what's between CORE-R2 and the internet.

```
CORE-R2# show ip interface brief | include GigabitEthernet0/3
GigabitEthernet0/3        203.0.113.20    YES manual administratively down    down

CORE-R2# show run interface GigabitEthernet0/3
interface GigabitEthernet0/3
 description WAN uplink to ISP
 ip address 203.0.113.20 255.255.255.252
 shutdown
```

## ROOT CAUSE

CORE-R2's WAN uplink interface (`Gi0/3`) is administratively shut down — most likely left disabled after maintenance (an interface audit, an ISP circuit test) and never re-enabled. With no WAN reachability, IKEv2 can't even send its first packet to Azure's gateway, which is why the tunnel interface shows up/down (locally configured and enabled) but the crypto session never forms: the fault is a full layer below the VPN stack, not in the VPN configuration itself.

## FIX

```
CORE-R2(config)# interface GigabitEthernet0/3
CORE-R2(config-if)# no shutdown
```

## VALIDATION

```
CORE-R2# show ip interface brief | include GigabitEthernet0/3
GigabitEthernet0/3        203.0.113.20    YES manual up                    up

CORE-R2# ping 203.0.113.10
Success rate is 100 percent (5/5)

CORE-R2# show crypto ikev2 sa
IPv4 Crypto IKEv2  SA
Tunnel-id Local                 Remote                fqdn      Status
1         203.0.113.20/500      203.0.113.10/500                READY

CORE-R2# show interface tunnel2
Tunnel2 is up, line protocol is up

CORE-R2# show ip bgp summary | include 169.254.20
169.254.20.1    4 65515      12      14       44    0    0 00:01:52        4
```
IKEv2 SA reaches READY, the tunnel interface's line protocol comes up, and the BGP session over it re-establishes with 4 prefixes received (Azure Prod + Dev, matching [../cloud-networking.md](../cloud-networking.md) §2.1). Confirm end-to-end with a ping from an HQ host to an Azure Prod VM, and check `az network vpn-connection show` reports `connectionStatus: Connected` from the Azure side too.
