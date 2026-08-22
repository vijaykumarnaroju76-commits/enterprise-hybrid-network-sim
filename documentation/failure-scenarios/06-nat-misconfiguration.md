# 06 — NAT Misconfiguration

## SYMPTOM

HQ users (VLAN 10, 10.0.10.0/24) can browse most external sites but a subset of internal SaaS-adjacent tools time out. Branch users (Site1-4) report no issue reaching the same destinations. DMZ-published services are unaffected.

## INVESTIGATION

Since only HQ VLAN 10 is affected and not the branches, and the Palo Alto firewall (`PA-EDGE-01`, per [../architecture.md](../architecture.md) §1) is the single perimeter NAT point everyone shares, start by comparing what source NAT is actually applying per zone/subnet rather than assuming the firewall as a whole is broken.

```
PA-EDGE-01> show session all filter source 10.0.10.15 destination-port 443
--------------------------------------------------------------------------
ID          Application    State   Type Flag  Src[Sport]/Zone/Proto (translated IP[Port])
104291      ssl            ACTIVE  FLOW       10.0.10.15[51422]/trust/6  (10.0.10.15[51422])
                            Vsys: vsys1
                            Dst[Dport]/Zone (translated IP[Port])
                            203.0.113.55[443]/untrust  (203.0.113.55[443])
```
The "translated IP" is identical to the source IP — no NAT is being applied at all for this flow, so the private `10.0.10.0/24` address is being sent straight to the internet, where it's unroutable and the return traffic never comes back. That matches "some external sites work, some don't" — anything that doesn't care about a bogus source (or that's actually reachable some other way) appears to work; anything strict times out.

## COMMANDS

```
PA-EDGE-01> show running nat-policy
1: HQ-Users-to-Internet {
    from trust;
    source [ 10.0.10.0/24 ];
    to untrust;
    destination [ any ];
    source-translation {
      dynamic-ip-and-port {
        translated-address [ 203.0.113.55 ];
      }
    }
  }
2: DMZ-to-Internet { ... }
3: Branch-to-Internet {
    from trust;
    source [ 10.1.0.0/16 10.2.0.0/16 10.3.0.0/16 10.4.0.0/16 ];
    ...
  }

PA-EDGE-01> show running nat-policy-rule-matched source 10.0.10.15 destination 203.0.113.55 destination-port 443 protocol 6
Matched rule: DMZ-to-Internet (rule #2)
```
Rule 1 (`HQ-Users-to-Internet`) exists and looks correctly scoped, but the session actually matched rule 2 (`DMZ-to-Internet`) instead — rule ordering matters on the Palo Alto, and rules are evaluated top-down until the first match. Check rule 2's source scope.

```
PA-EDGE-01> show running nat-policy | match "from trust" -A5
1: HQ-Users-to-Internet { from trust; source [ 10.0.10.0/24 ]; ... }
2: DMZ-to-Internet { from trust; source [ 10.0.10.0/24 10.0.100.0/24 ]; to untrust; ... source-translation { none; } }
```

## ROOT CAUSE

Rule 2 (`DMZ-to-Internet`), which was written to NAT the DMZ subnet (`10.0.100.0/24`) with no source translation intentionally (DMZ hosts have their own static NAT elsewhere), had `10.0.10.0/24` (HQ Users) accidentally left in its source list — likely copy-pasted while adding the DMZ subnet and never trimmed. Because rule 2 sits above rule 1 in evaluation order and its source list is broader than intended, HQ user traffic matches rule 2 first and gets `source-translation { none; }`, silently skipping NAT rule 1 entirely. Rule 1 itself was never wrong; it just never got evaluated for this traffic.

## FIX

```
PA-EDGE-01> configure
PA-EDGE-01# set rulebase nat rules DMZ-to-Internet source [ 10.0.100.0/24 ]
PA-EDGE-01# commit
```
Removes `10.0.10.0/24` from rule 2's source list so HQ user traffic falls through to rule 1 as originally intended.

## VALIDATION

```
PA-EDGE-01> show running nat-policy-rule-matched source 10.0.10.15 destination 203.0.113.55 destination-port 443 protocol 6
Matched rule: HQ-Users-to-Internet (rule #1)

PA-EDGE-01> show session all filter source 10.0.10.15 destination-port 443
ID          Application    State   Type Flag  Src[Sport]/Zone/Proto (translated IP[Port])
104388      ssl            ACTIVE  FLOW       10.0.10.15[51501]/trust/6  (203.0.113.55[24118])
```
The translated IP now correctly shows the NAT pool address instead of the private source. Re-test the previously-failing SaaS tools from an HQ client; also audit every other NAT rule for source-list overlap using `show running nat-policy | match source` to make sure this wasn't a one-off.
