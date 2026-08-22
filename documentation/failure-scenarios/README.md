# Failure Scenarios

Nine incidents, deliberately injected into the topology defined in [../architecture.md](../architecture.md), [../routing.md](../routing.md), and [../cloud-networking.md](../cloud-networking.md). Each one follows the same structure so they're fast to scan under pressure and useful as interview material:

```
SYMPTOM  ->  INVESTIGATION  ->  COMMANDS  ->  ROOT CAUSE  ->  FIX  ->  VALIDATION
```

| # | Scenario | Layer |
|---|---|---|
| [01](01-bgp-neighbor-down.md) | BGP neighbor down | On-prem <-> Cloud |
| [02](02-ospf-adjacency-failure.md) | OSPF adjacency failure | On-prem IGP |
| [03](03-wrong-route-advertisement.md) | Wrong route advertisement | BGP policy |
| [04](04-route-redistribution-loop.md) | Route redistribution loop | OSPF <-> BGP boundary |
| [05](05-vpn-tunnel-failure.md) | VPN tunnel failure | On-prem <-> Cloud transport |
| [06](06-nat-misconfiguration.md) | NAT misconfiguration | Perimeter (Palo Alto) |
| [07](07-firewall-policy-denial.md) | Firewall policy denial | Perimeter (Palo Alto) |
| [08](08-asymmetric-routing.md) | Asymmetric routing | End-to-end path |
| [09](09-cloud-route-table-error.md) | Cloud route-table error | AWS TGW / Azure UDR |

These are simulation exercises: symptoms and command output are what the design in this repo *would* produce given the described misconfiguration, used for training/interview prep and for validating the [automation](../../automation/) tooling's detection logic against known-bad states.
