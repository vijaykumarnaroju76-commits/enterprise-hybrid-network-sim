# Routing validation demo and live lab workflow

## Offline demo

Run from the repository root with Python 3.9+:

```bash
python3 automation/demo.py
python3 -m unittest discover -s tests -v
```

No additional packages or network access are needed. The demo creates synthetic
six-router state in memory and evaluates five scenarios:

| Scenario | Expected report result |
| --- | --- |
| Healthy | PASS |
| CORE-R1 neighbor in EXSTART | FAIL |
| CORE-R2 BGP peer in Active | FAIL |
| SITE1-RTR unparsed command output | FAIL |
| Recovered | PASS |

The demo exits zero only when every result matches its expectation. A FAIL report
for an injected fault is therefore a successful detection. Each Markdown report
in `automation/output/demo/` is labeled synthetic. No sessions, packets, VPNs, or
cloud resources are created by this demo.

## Collect evidence from your running lab

1. Build the topology described in `architecture.md` using your lab platform and
   properly licensed router images. Confirm management SSH reachability.
2. Review `automation/inventory.yaml` against your actual topology. Expected counts
   are minimum FULL OSPF and established BGP neighbors. Zero expected BGP means
   BGP is not applicable; it is not a check that BGP is disabled.
3. In `automation/`, install `requirements.txt` in a virtual environment and set
   `NET_USERNAME` and `NET_PASSWORD` locally. Do not publish credentials.
4. Run `collect_ospf_neighbors.py` and `collect_bgp_neighbors.py`, then
   `generate_validation_report.py`. The report command exits 1 for failed checks
   or invalid inputs and 0 for success.
5. In an isolated lab, introduce one documented routing failure. Repeat collection
   and validation, restore the original configuration, then collect recovery.
6. Capture separate ping/traceroute and routing-table evidence to prove forwarding
   and route recovery. Neighbor counts alone do not prove connectivity.

The report selects the newest filename for each collector independently. It does
not enforce freshness or guarantee the two collections belong to the same run.
Use a clean output directory per experiment, or select an archived experiment:

```bash
python3 automation/generate_validation_report.py \
  --inventory automation/inventory.yaml \
  --output-dir /path/to/one-experiment \
  --report /path/to/one-experiment/report.md
```

The input directory needs `ospf_neighbors_*.json` and `bgp_neighbors_*.json` in the
existing collector format. Review and sanitize captured files before publishing.
Record collection times, device versions, the exact change, and recovery steps.

## Interpretation and limits

- OSPF states such as EXSTART and 2WAY do not count toward FULL adjacency minimums.
  A 2WAY relationship can be legitimate on a broadcast segment; choose minimums
  that reflect the topology's expected FULL adjacencies.
- BGP `state_pfxrcd` containing a nonnegative integer means established, including
  zero received prefixes. It does not prove the required prefixes arrived.
- Raw strings, malformed rows, missing state fields, and collection failures fail
  closed for required protocols.
- These checks do not verify peer identity, route filtering, convergence time,
  cloud deployment, IPsec security associations, or end-to-end reachability.
- Terraform and the live-device collectors are unchanged by this update. This
  update's test results are not evidence that those integrations were executed.
