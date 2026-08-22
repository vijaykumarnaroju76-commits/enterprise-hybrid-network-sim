# 08 — Asymmetric Routing

## SYMPTOM

A stateful application between Site3 (10.3.1.0/24) and an AWS Prod host (172.31.1.20) fails intermittently — TCP handshakes sometimes complete, sometimes hang after the SYN. The Palo Alto firewall's session table shows some flows stuck half-open.

## INVESTIGATION

Intermittent failure specifically on a *stateful* app, with routing otherwise looking healthy, is the classic signature of asymmetric routing: the outbound and return paths cross different firewalls or NAT points, and a stateful device on one path drops return traffic it never saw the opening handshake for. Trace both directions explicitly instead of trusting a single `show ip route`.

```
CORE-R2# traceroute 172.31.1.20 source 10.3.1.1
  1  192.168.1.9   (Site3 -> CORE-R2)
  2  169.254.20.1  (CORE-R2 -> Azure VPN GW)   <-- outbound via Azure?!
  3  ...
```
Outbound traffic from Site3 to an AWS destination is transiting the Azure tunnel, not the AWS tunnel. Compare against the return path.

## COMMANDS

```
CORE-R1# show ip bgp 172.31.1.0/24
BGP routing table entry for 172.31.1.0/24
   169.254.10.1 (via CORE-R1, AWS primary) from 169.254.10.1, localpref 100, best
   169.254.20.5 (via CORE-R1, Azure backup) from 169.254.20.5, localpref 50

CORE-R2# show ip bgp 172.31.1.0/24
BGP routing table entry for 172.31.1.0/24
   169.254.10.5 (via CORE-R2, AWS backup) from 169.254.10.5, localpref 100   <-- should be 50
   169.254.20.1 (via CORE-R2, Azure primary) from 169.254.20.1, localpref 50
```
On CORE-R2, the **backup** AWS path (learned from `169.254.10.5`, which per [../routing.md](../routing.md) §2 should carry `local-preference 50` via the `AWS-BACKUP-IN` route-map) is instead showing `localpref 100` — the same as the primary. With both paths at equal preference, CORE-R2 is choosing the AWS route via a different tiebreaker (likely lowest neighbor address or most recent), while the return traffic from AWS still comes back through CORE-R1 (AWS's genuinely-primary tunnel), creating asymmetry: Site3's outbound traffic for AWS destinations goes out CORE-R2 (wrongly, since CORE-R2 to AWS is meant to be backup-only) while AWS's replies come back via CORE-R1.

## ROOT CAUSE

```
CORE-R2# show route-map AWS-BACKUP-IN
route-map AWS-BACKUP-IN, permit, sequence 10
    Match clauses:
      ip address prefix-list CLOUD-PREFIXES
    Set clauses:
                                              <-- no "set local-preference 50"
```
The `set local-preference 50` line is missing from `AWS-BACKUP-IN` on CORE-R2 — the route-map still matches and permits the routes (so the session and prefixes look completely normal in `show ip bgp summary`), but without the `set` clause every route through it keeps the BGP default local-preference of 100, tying with the genuinely-primary session. CORE-R2 then has two equal-preference paths to AWS and picks between them using a lower-priority tiebreaker instead of correctly always deferring to CORE-R1's primary session — which is exactly the kind of failure that passes every "is the session up" check while still being wrong.

## FIX

```
CORE-R2(config)# route-map AWS-BACKUP-IN permit 10
CORE-R2(config-route-map)# set local-preference 50
```

## VALIDATION

```
CORE-R2# show ip bgp 172.31.1.0/24
BGP routing table entry for 172.31.1.0/24
   169.254.10.5 (via CORE-R2, AWS backup) from 169.254.10.5, localpref 50
   169.254.20.1 (via CORE-R2, Azure primary) from 169.254.20.1, localpref 100, best

CORE-R2# traceroute 172.31.1.20 source 10.3.1.1
  1  192.168.1.18  (Site3 via CORE-R2 -> CORE-R1, since CORE-R2 no longer prefers AWS locally)
  2  169.254.10.1  (CORE-R1 -> AWS, primary)
```
Outbound and return paths now both transit CORE-R1's primary AWS session. Confirm with the firewall session table that no new half-open sessions accumulate over a sustained test, and re-check `AWS-BACKUP-IN`/`AZURE-BACKUP-IN` on **both** core routers side by side to make sure this wasn't a config drift affecting more than one route-map.
