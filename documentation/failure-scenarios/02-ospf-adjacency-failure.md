# 02 — OSPF Adjacency Failure

## SYMPTOM

Site2 (10.2.0.0/16) has lost reachability to everything beyond its directly-connected subnets, including HQ, other branches, and both clouds. Site1, Site3, Site4 are unaffected.

```
CORE-R1# show ip ospf neighbor
Neighbor ID     Pri   State           Dead Time   Address         Interface
10.255.0.2      1     FULL/  -        00:00:33    192.168.1.18    Gi0/0.10
10.255.0.11     1     FULL/DR         00:00:31    192.168.1.1     Gi0/1
                                                                    Gi0/2   <-- Site2 missing entirely
```

## INVESTIGATION

No neighbor entry at all for Site2 (not even stuck in a partial state like EXSTART) means Hello packets aren't being exchanged — check whether the interface itself is even in OSPF, before looking at anything protocol-specific.

```
CORE-R1# show ip ospf interface brief
Interface    PID   Area            IP Address/Mask    Cost  State Nbrs F/C
Gi0/1        1     10              192.168.1.2/30     1     DR    1/1
Gi0/0.10     1     0               192.168.1.17/30    1     P2P   1/1
                                                                        <-- Gi0/2 not listed
```

`Gi0/2` (the link to SITE2-RTR) doesn't appear in the OSPF interface table at all, despite being wired and configured per [../architecture.md](../architecture.md) §3.2.

## COMMANDS

```
CORE-R1# show ip interface brief | include Gi0/2
GigabitEthernet0/2        192.168.1.5     YES manual up                    up

CORE-R1# show run interface Gi0/2
interface GigabitEthernet0/2
 ip address 192.168.1.5 255.255.255.252
 ip ospf 1 area 20        <-- should be area 10

CORE-R1# show ip ospf | include area 10 area 20
    Area BACKBONE(0)
    Area 10
    Area 20
```
The interface is up/up and has an IP address — the physical/IP layer is fine, which is why nothing on Site2's side shows a fault either; this is purely an OSPF area mismatch.

## ROOT CAUSE

`ip ospf 1 area 20` on CORE-R1's `Gi0/2` — a fat-fingered area number instead of `area 10`, the branch area defined in [../architecture.md](../architecture.md) §5. Since area 20 doesn't exist anywhere else in the design, the router silently creates it locally and never forms an adjacency, because SITE2-RTR is sending Hellos for area 10 and CORE-R1 is listening for Hellos on that link for area 20 — an OSPF area mismatch is dropped silently at the Hello stage, with no log message on either side by default, which is why this can sit undetected until someone actually loses connectivity.

## FIX

```
CORE-R1(config)# interface GigabitEthernet0/2
CORE-R1(config-if)# no ip ospf 1 area 20
CORE-R1(config-if)# ip ospf 1 area 10
```

## VALIDATION

```
CORE-R1# show ip ospf neighbor
Neighbor ID     Pri   State           Dead Time   Address         Interface
10.255.0.2      1     FULL/  -        00:00:35    192.168.1.18    Gi0/0.10
10.255.0.11     1     FULL/DR         00:00:38    192.168.1.1     Gi0/1
10.255.0.12     1     FULL/DR         00:00:39    192.168.1.5     Gi0/2

CORE-R1# show ip route ospf | include 10.2.0.0
O IA  10.2.0.0/16 [110/11] via 192.168.1.6, 00:00:41, GigabitEthernet0/2
```
Adjacency reaches FULL, Site2's `/16` reappears in the routing table, and from a Site2 host `ping` to both an HQ server and an AWS Prod host succeeds.
