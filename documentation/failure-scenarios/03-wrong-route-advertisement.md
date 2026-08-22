# 03 — Wrong Route Advertisement

## SYMPTOM

AWS-side team reports their route table for the VPN attachment now contains a branch management subnet, `10.2.99.0/24` (Site2 OOB/management — see [../architecture.md](../architecture.md) §3.1), which should never leave the enterprise. Security flags it as a scope violation during a routine TGW route-table audit.

## INVESTIGATION

Per [../routing.md](../routing.md) §4, only the `10.0.0.0/8` aggregate should ever be sent to either cloud — nothing more specific. Start on the router actually holding the eBGP session to AWS.

```
CORE-R1# show ip bgp neighbors 169.254.10.1 advertised-routes
   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.0.0/8       0.0.0.0                  0         32768 i
*> 10.2.99.0/24     0.0.0.0                  0         32768 i    <-- shouldn't be here
```

The aggregate is present as expected, but so is a specific /24. Since `aggregate-address ... summary-only` is supposed to suppress the more-specific routes it summarizes, its presence here means either the aggregate statement is missing `summary-only`, or the /24 is coming from somewhere `summary-only` doesn't apply to — a directly-configured `network` statement bypasses aggregate suppression entirely.

## COMMANDS

```
CORE-R1# show run | section router bgp
router bgp 65000
 network 10.0.0.0 mask 255.0.0.0
 network 10.2.99.0 mask 255.255.255.0     <-- leftover network statement
 aggregate-address 10.0.0.0 255.0.0.0 summary-only
 !
 address-family ipv4
  neighbor 169.254.10.1 route-map AWS-OUT out

CORE-R1# show route-map AWS-OUT
route-map AWS-OUT, permit, sequence 10
  Match clauses:
    ip address prefix-list ADVERTISE-TO-CLOUD
CORE-R1# show ip prefix-list ADVERTISE-TO-CLOUD
ip prefix-list ADVERTISE-TO-CLOUD: 1 entries
   seq 5 permit 10.0.0.0/8
```

The `AWS-OUT` route-map and its prefix-list are configured correctly per [../routing.md](../routing.md) §4 — but a `network 10.2.99.0 mask 255.255.255.0` statement injects the /24 directly into the BGP table as a locally-originated route, and locally-originated routes with `weight 32768` are not evaluated against outbound route-maps the same way learned routes are re-filtered; the route-map still applies here, so the real question is why it passed.

```
CORE-R1# show ip bgp 10.2.99.0/24
BGP routing table entry for 10.2.99.0/24
  Advertised to update-groups:
     1
  Local, weight 32768
  Refresh Epoch 1
  0.0.0.0 from 0.0.0.0 (10.255.0.1)
```
It passed because `ADVERTISE-TO-CLOUD` only matches `10.0.0.0/8` **exactly** (no `le`/`ge`), and route-map `match ip address prefix-list` on an *exact-length* prefix-list entry does not block a *different*, more-specific prefix from matching a broader intent — the actual bug is that `10.2.99.0/24` was never supposed to be in the BGP table as its own entry at all.

## ROOT CAUSE

A leftover `network 10.2.99.0 mask 255.255.255.0` statement, most likely added during a troubleshooting session to test Site2 management reachability and never removed. It bypasses the intended aggregate-only design because it originates the /24 as a first-class BGP route rather than relying on OSPF redistribution + aggregation, so `summary-only` (which only suppresses more-specifics it itself generated from redistributed routes) never touches it.

## FIX

```
CORE-R1(config)# router bgp 65000
CORE-R1(config-router)# no network 10.2.99.0 mask 255.255.255.0
```

Also tighten the outbound filter to explicitly deny anything more specific than the aggregate, so a future stray `network` statement can't repeat this:
```
ip prefix-list ADVERTISE-TO-CLOUD seq 5 permit 10.0.0.0/8
ip prefix-list ADVERTISE-TO-CLOUD seq 10 deny 0.0.0.0/0 le 32
```

## VALIDATION

```
CORE-R1# show ip bgp neighbors 169.254.10.1 advertised-routes
   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.0.0/8       0.0.0.0                  0         32768 i
```

```bash
# AWS side
aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id <id> \
  --filters Name=state,Values=active
# confirm only 10.0.0.0/8 present, no /24s
```
Only the aggregate remains. Have Security re-run their TGW route-table audit to close the finding, and check `10.1.99.0/24`, `10.3.99.0/24`, `10.4.99.0/24` were never advertised either (they weren't, per the BGP table check above — only Site2's was ever added).
