# 07 — Firewall Policy Denial

## SYMPTOM

After onboarding a new AWS Prod application tier (172.31.1.0/24, per [../cloud-networking.md](../cloud-networking.md) §1.1), HQ servers (VLAN 20, 10.0.20.0/24) cannot reach it. Branch-to-AWS traffic through the same firewall is unaffected. Routing looks correct — `show ip route` on CORE-R1 has the AWS Prod prefix.

## INVESTIGATION

Since routing is confirmed fine and the perimeter firewall (`PA-EDGE-01`) sits in the path between the HQ trust zone and anything that isn't a directly-connected LAN segment, check whether the traffic is even reaching the far side of the firewall, before touching routing again.

```
PA-EDGE-01> show session all filter source 10.0.20.30 destination 172.31.1.10
--------------------------------------------------------------------------
                            (no matching sessions found)

PA-EDGE-01> show log traffic direction backward query "(addr.src in 10.0.20.30) and (addr.dst in 172.31.1.10)"
receive_time         type    from    to      rule                    action
2026/08/20 14:02:11  end     trust   cloud-prod  Cloud-Prod-Access   deny
```
No session was created at all — the flow was denied outright, and `show log traffic` confirms which rule denied it.

## COMMANDS

```
PA-EDGE-01> show rulebase security rules Cloud-Prod-Access
"Cloud-Prod-Access" {
    from trust;
    to cloud-prod;
    source [ 10.0.10.0/24 10.1.0.0/16 10.2.0.0/16 10.3.0.0/16 10.4.0.0/16 ];
    destination [ 172.31.1.0/24 172.32.1.0/24 ];
    application [ ssl web-browsing ];
    action allow;
}
```
The rule exists, permits the right zones and destinations, and even already includes the new subnet — but `10.0.20.0/24` (HQ Servers, VLAN 20) is missing from the source list entirely. Users (`10.0.10.0/24`) and every branch are listed; the HQ server subnet was never added.

## ROOT CAUSE

`Cloud-Prod-Access` was originally written for user-initiated traffic to cloud apps and only ever included the branch and HQ-user subnets. When the new AWS Prod app tier was onboarded, the corresponding *destination* (`172.31.1.0/24`) was added to the existing rule, but nobody added the HQ **server** subnet as an allowed *source* — server-to-server traffic to the new tier was never in scope of the original rule, and there wasn't a separate rule for it either. This isn't a broken rule, it's an incomplete one: the change request covered the cloud side of the access path and missed the on-prem source side.

## FIX

```
PA-EDGE-01> configure
PA-EDGE-01# set rulebase security rules Cloud-Prod-Access source [ 10.0.10.0/24 10.0.20.0/24 10.1.0.0/16 10.2.0.0/16 10.3.0.0/16 10.4.0.0/16 ]
PA-EDGE-01# commit
```
Adding `10.0.20.0/24` to the existing rule (rather than writing a new one) keeps a single source of truth for "who can reach Cloud-Prod" instead of splitting it across multiple rules that could drift independently.

## VALIDATION

```
PA-EDGE-01> show log traffic direction backward query "(addr.src in 10.0.20.30) and (addr.dst in 172.31.1.10)"
receive_time         type    from    to      rule                    action
2026/08/20 14:19:47  end     trust   cloud-prod  Cloud-Prod-Access   allow

PA-EDGE-01> show session all filter source 10.0.20.30 destination 172.31.1.10
ID          Application    State   Type Flag  Src[Sport]/Zone/Proto
104512      ssl            ACTIVE  FLOW       10.0.20.30[52001]/trust/6
```
A session now establishes and the log shows `allow` against the correct rule. Confirm application-level connectivity from an HQ server, and check whether any *other* recently-onboarded destination subnet has the same "destination added, source not reviewed" gap by diffing `Cloud-Prod-Access`'s source list against the full subnet table in [../architecture.md](../architecture.md) §3.1.
