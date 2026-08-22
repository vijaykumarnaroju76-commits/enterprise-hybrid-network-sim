# 04 — Route Redistribution Loop

## SYMPTOM

Both core routers show climbing CPU, `show ip route` for the on-prem aggregate churns continuously, and branch sites report intermittent flapping reachability to *everything*, not just one cloud.

```
CORE-R1# show processes cpu | include OSPF|BGP
   142   OSPF Router          38.42%   ospf-1
   156   BGP Scanner          22.10%   bgp-scanner

CORE-R1# show ip route 10.0.0.0
Routing entry for 10.0.0.0/8
  Known via "ospf 1", distance 110, metric 20, type extern 1
  Last update from 10.255.0.2 00:00:02 ago
```
The `10.0.0.0/8` aggregate — which CORE-R1 itself originates into BGP — is showing up as a **learned OSPF external route**, one hop away, sourced from CORE-R2.

## INVESTIGATION

Per [../routing.md](../routing.md) §3, redistribution should be one-directional and filtered at each boundary: OSPF never feeds BGP directly (only the local `network`/`aggregate-address` statements do), and BGP-into-OSPF is filtered to cloud prefixes only via `CLOUD-PREFIXES`. If the on-prem aggregate itself is coming back in via OSPF, that filter isn't doing its job on at least one router.

```
CORE-R2# show run | section router ospf
router ospf 1
 redistribute bgp 65000 subnets metric 20 metric-type 1     <-- no route-map!
```

## COMMANDS

```
CORE-R2# show ip prefix-list CLOUD-PREFIXES
ip prefix-list CLOUD-PREFIXES: 4 entries
   seq 5 permit 172.30.0.0/16 le 24
   seq 10 permit 172.31.0.0/16 le 24
   seq 15 permit 172.32.0.0/16 le 24
   seq 20 permit 172.33.0.0/16 le 24

CORE-R2# show ip bgp | include 10.0.0.0
*> 10.0.0.0/8       0.0.0.0                  0         32768 i
```
The prefix-list is correctly scoped, but the `redistribute bgp 65000 subnets` statement on CORE-R2 has no `route-map CLOUD-TO-OSPF` attached to it at all — the prefix-list exists but was never wired to the redistribution statement, so **every** BGP route CORE-R2 holds, including its own locally-originated `10.0.0.0/8`, is redistributed into OSPF.

## ROOT CAUSE

CORE-R1 originates `10.0.0.0/8` into BGP (weight 32768, local). CORE-R2 learns it over iBGP, and CORE-R2's OSPF redistribution has no filter, so it re-injects `10.0.0.0/8` into OSPF as an external route. CORE-R1 then sees its own aggregate reflected back via OSPF (E1, cost 20, from CORE-R2) — since that's a different route source/metric than its locally-originated BGP entry, both routers now hold two paths to the same aggregate and OSPF SPF + BGP best-path recalculation trigger each other continuously: OSPF change -> triggers a BGP table walk (next-hop reachability) -> which doesn't change BGP's best path but does re-touch the RIB -> which OSPF's redistribution (still unfiltered) re-announces -> repeat. This is the two-box, two-protocol version of a redistribution loop: neither protocol is misbehaving on its own, the boundary between them is unfiltered in one direction on one router.

## FIX

```
CORE-R2(config)# router ospf 1
CORE-R2(config-router)# no redistribute bgp 65000 subnets metric 20 metric-type 1
CORE-R2(config-router)# redistribute bgp 65000 subnets route-map CLOUD-TO-OSPF metric 20 metric-type 1
```
(`CLOUD-TO-OSPF` already exists correctly on CORE-R1 per [../routing.md](../routing.md) §3 — this fix brings CORE-R2 into parity with it. As a second line of defense, deny the on-prem aggregate explicitly at the top of `CLOUD-PREFIXES` on both routers so a future missing route-map degrades safely instead of looping:)
```
ip prefix-list CLOUD-PREFIXES seq 1 deny 10.0.0.0/8 le 32
```

## VALIDATION

```
CORE-R1# show processes cpu | include OSPF|BGP
   142   OSPF Router           0.61%   ospf-1
   156   BGP Scanner           0.15%   bgp-scanner

CORE-R2# show ip route 10.0.0.0
% Network not in table          <-- correct: only CORE-R1 originates it, and CORE-R2 reaches it via iBGP, not OSPF

CORE-R1# show ip ospf database | include 10.0.0.0
                                                             <-- no LSA for the on-prem aggregate
```
CPU returns to baseline, the aggregate no longer appears as an OSPF-learned route on either router, and branch-site connectivity to HQ/AWS/Azure stops flapping. Re-run the automation validation report (see [`../../automation/`](../../automation/)) to confirm no other router in the topology has the same unfiltered redistribute statement.
