\# Routing Design: OSPF + BGP + Redistribution + Redundancy

Addressing, ASNs, and router IDs referenced below are defined in [architecture.md]\(architecture.md). This document covers the actual protocol configuration and shows the verification output an engineer should see once the design converges correctly.

\## 1. OSPF (Interior Gateway Protocol)

The enterprise uses a multi-area OSPF design. Area 0 forms the backbone between CORE-R1 and CORE-R2. Each branch uses its own stub area so every non-backbone area connects directly to Area 0 through an ABR.

| Branch | OSPF Area | ABR |
|---|---:|---|
| Site1 | 10 | CORE-R1 |
| Site2 | 20 | CORE-R1 |
| Site3 | 30 | CORE-R2 |
| Site4 | 40 | CORE-R2 |

This prevents a discontinuous non-backbone area across the Area 0 core.

### CORE-R1 — ABR for Areas 10 and 20

```text
router ospf 1
 router-id 10.255.0.1
 area 10 stub no-summary
 area 20 stub no-summary
 area 10 range 10.1.0.0 255.255.0.0
 area 20 range 10.2.0.0 255.255.0.0
 passive-interface default
 no passive-interface GigabitEthernet0/0.10
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 10.255.0.1 0.0.0.0 area 0
 network 192.168.1.16 0.0.0.3 area 0
 network 192.168.1.0 0.0.0.3 area 10
 network 192.168.1.4 0.0.0.3 area 20
 timers throttle spf 50 100 5000
 timers throttle lsa 50 100 5000
```

### CORE-R2 — ABR for Areas 30 and 40

```text
router ospf 1
 router-id 10.255.0.2
 area 30 stub no-summary
 area 40 stub no-summary
 area 30 range 10.3.0.0 255.255.0.0
 area 40 range 10.4.0.0 255.255.0.0
 passive-interface default
 no passive-interface GigabitEthernet0/0.10
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 10.255.0.2 0.0.0.0 area 0
 network 192.168.1.16 0.0.0.3 area 0
 network 192.168.1.8 0.0.0.3 area 30
 network 192.168.1.12 0.0.0.3 area 40
 timers throttle spf 50 100 5000
 timers throttle lsa 50 100 5000
```

### SITE1-RTR — Area 10

```text
router ospf 1
 router-id 10.255.0.11
 area 10 stub
 passive-interface default
 no passive-interface GigabitEthernet0/0
 network 10.255.0.11 0.0.0.0 area 10
 network 10.1.1.0 0.0.0.255 area 10
 network 10.1.2.0 0.0.0.255 area 10
 network 10.1.99.0 0.0.0.255 area 10
 network 192.168.1.0 0.0.0.3 area 10
```

Site2 follows the same pattern in Area 20, Site3 in Area 30, and Site4 in Area 40.

User, server, and management VLAN interfaces remain **passive**. Their prefixes are advertised into OSPF, but those LAN interfaces do not attempt to form OSPF adjacencies with endpoints.

Each branch is configured as a totally stubby area at its ABR, so branch routers receive a default route rather than individual BGP-redistributed external routes.

## 2. BGP (Enterprise <-> Cloud)

\### CORE-R1 — primary AWS peer, backup Azure peer

\`\`\`

router bgp 65000

 bgp router-id 10.255.0.1

 bgp log-neighbor-changes

 neighbor 10.255.0.2 remote-as 65000        ! iBGP to CORE-R2

 neighbor 10.255.0.2 update-source Loopback0

 neighbor 10.255.0.2 next-hop-self

 neighbor 169.254.10.1 remote-as 64512      ! eBGP to AWS TGW, primary

 neighbor 169.254.20.5 remote-as 65515      ! eBGP to Azure VGW, backup

 !

 address-family ipv4

  network 10.0.0.0 mask 255.0.0.0

  aggregate-address 10.0.0.0 255.0.0.0 summary-only

  neighbor 10.255.0.2 activate

  neighbor 169.254.10.1 activate

  neighbor 169.254.10.1 route-map AWS-IN in

  neighbor 169.254.10.1 route-map AWS-OUT out

  neighbor 169.254.20.5 activate

  neighbor 169.254.20.5 route-map AZURE-BACKUP-IN in

  neighbor 169.254.20.5 route-map AZURE-OUT out

 exit-address-family

\`\`\`

\### CORE-R2 — primary Azure peer, backup AWS peer (mirror of CORE-R1)

\`\`\`

router bgp 65000

 bgp router-id 10.255.0.2

 neighbor 10.255.0.1 remote-as 65000

 neighbor 10.255.0.1 update-source Loopback0

 neighbor 10.255.0.1 next-hop-self

 neighbor 169.254.20.1 remote-as 65515      ! eBGP to Azure VGW, primary

 neighbor 169.254.10.5 remote-as 64512      ! eBGP to AWS TGW, backup

 !

 address-family ipv4

  network 10.0.0.0 mask 255.0.0.0

  aggregate-address 10.0.0.0 255.0.0.0 summary-only

  neighbor 10.255.0.1 activate

  neighbor 169.254.20.1 activate

  neighbor 169.254.20.1 route-map AZURE-IN in

  neighbor 169.254.20.1 route-map AZURE-OUT out

  neighbor 169.254.10.5 activate

  neighbor 169.254.10.5 route-map AWS-BACKUP-IN in

  neighbor 169.254.10.5 route-map AWS-OUT out

 exit-address-family

\`\`\`

\## 3. Route Redistribution

Redistribution happens in exactly two places, both at the core, both filtered — an unfiltered \`redistribute ospf into bgp\` / \`redistribute bgp into ospf\` on the same pair of routers is precisely how routing loops form (see [failure-scenarios/04-route-redistribution-loop.md]\(failure-scenarios/04-route-redistribution-loop.md)).

\*\***OSPF -> BGP:**\*\* never redistributed directly. Only the locally-originated \`network 10.0.0.0 mask 255.0.0.0\` statement plus \`aggregate-address ... summary-only\` puts the on-prem aggregate into BGP. This avoids injecting 20 individual branch /24s into two clouds and avoids any possibility of re-advertising a route BGP just learned.

\*\***BGP -> OSPF:**\*\* cloud prefixes are redistributed into OSPF as external routes, filtered to only the cloud aggregates:

\`\`\`

router ospf 1

 redistribute bgp 65000 subnets route-map CLOUD-TO-OSPF metric 20 metric-type 1

!

ip prefix-list CLOUD-PREFIXES seq 5 permit 172.30.0.0/16 le 24

ip prefix-list CLOUD-PREFIXES seq 10 permit 172.31.0.0/16 le 24

ip prefix-list CLOUD-PREFIXES seq 15 permit 172.32.0.0/16 le 24

ip prefix-list CLOUD-PREFIXES seq 20 permit 172.33.0.0/16 le 24

!

route-map CLOUD-TO-OSPF permit 10

 match ip address prefix-list CLOUD-PREFIXES

\`\`\`

\`metric-type 1\` (E1) is used deliberately instead of the OSPF default E2, so the redistributed cost accumulates across hops and branch routers pick the topologically-nearer core router rather than always preferring whichever core router redistributed the route first.

\## 4. Route Filtering

Filtering enforces two things: the on-prem aggregate only (never branch /24s or the WAN transit /30s) goes to the clouds, and Dev/Prod stay separated at the routing layer, not just via security groups.

\`\`\`

ip prefix-list ADVERTISE-TO-CLOUD seq 5 permit 10.0.0.0/8

route-map AWS-OUT permit 10

 match ip address prefix-list ADVERTISE-TO-CLOUD

route-map AWS-OUT deny 20

route-map AZURE-OUT permit 10

 match ip address prefix-list ADVERTISE-TO-CLOUD

route-map AZURE-OUT deny 20

! Primary AWS session: accept full routes from AWS

route-map AWS-IN permit 10

 match ip address prefix-list CLOUD-PREFIXES

! Backup AWS session (on CORE-R2): accept but de-preference so primary always wins

route-map AWS-BACKUP-IN permit 10

 match ip address prefix-list CLOUD-PREFIXES

 set local-preference 50

route-map AZURE-IN permit 10

 match ip address prefix-list CLOUD-PREFIXES

route-map AZURE-BACKUP-IN permit 10

 match ip address prefix-list CLOUD-PREFIXES

 set local-preference 50

\`\`\`

Default \`local-preference\` is 100, so the backup sessions (set to 50) only win when the primary session is down — this is the redundancy mechanism, not a routing protocol failover, which keeps convergence to a single BGP best-path recalculation instead of an IGP reconvergence.

\## 5. Redundancy Summary

\| Failure | What takes over | Mechanism |

\|---|---|---|

\| CORE-R1 <-> AWS tunnel down | CORE-R2 <-> AWS backup tunnel | BGP session down -> local-pref 50 path via CORE-R2 becomes best |

\| CORE-R2 <-> Azure tunnel down | CORE-R1 <-> Azure backup tunnel | Same, mirrored |

\| CORE-R1 fails entirely | CORE-R2 carries both clouds | iBGP + OSPF Area 0 reconverge, both cloud sessions already exist on CORE-R2 |

\| WAN link Core<->Site down | Alternate ABR path (if dual-homed) or default route via surviving ABR | OSPF SPF recalculation, \`timers throttle spf 50 100 5000\` |

\| Single cloud VPN tunnel flaps | No churn on the other tunnel | Each tunnel is an independent BGP session; flapping one doesn't reset the other |

\## 6. Verification Commands and Expected Output

These are the standard commands to confirm the design above is actually converged, run from \`CORE-R1\`.

\### \`show ip ospf neighbor\`

\`\`\`

CORE-R1# show ip ospf neighbor

Neighbor ID     Pri   State           Dead Time   Address         Interface

10.255.0.2      1     FULL/  -        00:00:38    192.168.1.18    Gi0/0.10

10.255.0.11     1     FULL/DR         00:00:32    192.168.1.1     Gi0/1

10.255.0.12     1     FULL/DR         00:00:39    192.168.1.5     Gi0/2

\`\`\`

\### \`show ip bgp summary\`

\`\`\`

CORE-R1# show ip bgp summary

BGP router identifier 10.255.0.1, local AS number 65000

BGP table version is 42, main routing table version 42

24 network entries using 3456 bytes of memory

Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd

10.255.0.2      4 65000     512     509       42    0    0 03:41:15        3

169.254.10.1    4 64512     498     501       42    0    0 03:40:02        6

169.254.20.5    4 65515     490     493       42    0    0 03:39:47        4

\`\`\`

\`169.254.10.1\` (AWS, primary) is Established with 6 prefixes received (the full AWS Prod + Dev breakdown). \`169.254.20.5\` (Azure, backup path on this router) is also Established but its routes are held at \`local-preference 50\`, so they only surface in the RIB if the primary Azure session on CORE-R2 goes down.

\### \`show ip route\`

\`\`\`

CORE-R1# show ip route

Gateway of last resort is 169.254.10.1 to network 0.0.0.0

O IA  10.1.0.0/16 [110/11] via 192.168.1.1, 00:12:03, GigabitEthernet0/1

O IA  10.2.0.0/16 [110/11] via 192.168.1.5, 00:12:03, GigabitEthernet0/2

O IA  10.3.0.0/16 [110/21] via 192.168.1.18, 00:41:15, GigabitEthernet0/0.10

O IA  10.4.0.0/16 [110/21] via 192.168.1.18, 00:41:15, GigabitEthernet0/0.10

B    172.31.0.0/16 [20/0] via 169.254.10.1, 03:40:02

B    172.30.0.0/16 [20/0] via 169.254.10.1, 03:40:02

B    172.32.0.0/16 [20/0] via 169.254.10.1, 03:40:02

B    172.33.0.0/16 [20/0] via 169.254.10.1, 03:40:02

\`\`\`

Note the cloud prefixes are \`B\` here (learned via BGP and preferred over the redistributed OSPF-E1 copy that Site routers see) — CORE-R1 itself never needs the redistributed version since it's the BGP speaker; only Site1-4 see them as \`O E1\`.

\### \`show ip bgp\`

\`\`\`

CORE-R1# show ip bgp

BGP table version is 42, local router ID is 10.255.0.1

Status codes: s suppressed, d damped, h history, \* valid, > best, i - internal

   Network          Next Hop            Metric LocPrf Weight Path

\*> 10.0.0.0/8       0.0.0.0                  0         32768 i

\*> 172.30.0.0/16    169.254.10.1             0    100      0 64512 i

\*  172.30.0.0/16    169.254.20.5             0     50      0 65515 64512 i

\*> 172.31.0.0/16    169.254.10.1             0    100      0 64512 i

\*> 172.32.0.0/16    169.254.20.5             0    100      0 65515 i

\*> 172.33.0.0/16    169.254.20.5             0    100      0 65515 i

\`\`\`

The AS path \`65515 64512\` on the backup entry for \`172.30.0.0/16\` shows Azure is transiting a route it in turn learned from a full-mesh on-prem redistribution — this is exactly the shape to watch for the redistribution-loop scenario in Upgrade 4.

\### \`show ip protocols\`

\`\`\`

CORE-R1# show ip protocols

Routing Protocol is "ospf 1"

  Router ID 10.255.0.1

  Redistributing: bgp 65000

  Area 0, Area 10 active

  Reference bandwidth unit is 100 mbps

Routing Protocol is "bgp 65000"

  Router ID 10.255.0.1

  IGP synchronization is disabled

  Neighbor(s):

    10.255.0.2      iBGP

    169.254.10.1    eBGP AS 64512 (AWS TGW, primary)

    169.254.20.5    eBGP AS 65515 (Azure VGW, backup)

  Maximum path: 1

  Routing for Networks:

    10.0.0.0/8

\`\`\`

Continue to [cloud-networking.md]\(cloud-networking.md) for how the AWS and Azure sides of these BGP sessions (Transit Gateway, VPN Gateway, route tables, UDRs) are actually built.