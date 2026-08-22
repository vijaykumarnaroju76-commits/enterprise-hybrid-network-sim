# 01 — BGP Neighbor Down

## SYMPTOM

Branch users report AWS-hosted application (Prod VPC, 172.31.1.0/24) is unreachable. Azure connectivity is unaffected.

```
CORE-R1# show ip bgp summary
BGP router identifier 10.255.0.1, local AS number 65000

Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
10.255.0.2      4 65000     520     518       42    0    0 03:52:01        3
169.254.10.1    4 64512       0       0        1    0    0 00:14:22 Active
169.254.20.5    4 65515     501     504       42    0    0 03:51:47        4
```

`169.254.10.1` (AWS TGW, CORE-R1's primary session) is stuck in **Active** — it's trying to establish TCP but never completes the BGP handshake. `MsgRcvd`/`MsgSent` are 0.

## INVESTIGATION

Active (not Idle) means the router can reach the peer at the IP layer and is attempting a TCP connection, but the connection isn't completing — that rules out a routing/reachability problem and points at TCP port 179 or a config mismatch (wrong remote-as, wrong peer IP after a tunnel renumber).

```
CORE-R1# show ip bgp neighbors 169.254.10.1
BGP neighbor is 169.254.10.1, remote AS 64512, external link
  BGP state = Active
  Last read never, last write never
  Connections established 0; dropped 0
  Connection state is CLOSED

CORE-R1# ping 169.254.10.1
Success rate is 100 percent (5/5)

CORE-R1# show interface tunnel0
Tunnel0 is up, line protocol is up
```

Tunnel and IP reachability are fine. Next, confirm the peer is actually listening.

## COMMANDS

```
CORE-R1# telnet 169.254.10.1 179
Trying 169.254.10.1 ... Open
% Connection reset by peer

CORE-R1# show run | section router bgp
router bgp 65000
 neighbor 169.254.10.1 remote-as 65412        <-- should be 64512
```

## ROOT CAUSE

`neighbor 169.254.10.1 remote-as 65412` — a transposed digit against the AWS TGW's actual ASN of `64512` (see [../routing.md](../routing.md) §2). AWS's side sends an OPEN message with AS 64512; CORE-R1, expecting 65412, rejects it and resets the session, and the state machine falls back to Active on the next retry. TCP itself completes fine (that's why `telnet ... 179` opens before resetting), which is why ping/tunnel checks looked healthy — the fault is entirely inside the BGP OPEN negotiation, one layer up from anything ping or interface status can show.

## FIX

```
CORE-R1(config)# router bgp 65000
CORE-R1(config-router)# no neighbor 169.254.10.1 remote-as 65412
CORE-R1(config-router)# neighbor 169.254.10.1 remote-as 64512
```

## VALIDATION

```
CORE-R1# show ip bgp summary
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
169.254.10.1    4 64512       8       9       43    0    0 00:00:41        6

CORE-R1# show ip bgp neighbors 169.254.10.1 | include BGP state
  BGP state = Established, up for 00:00:41

CORE-R1# show ip route 172.31.1.0
Routing entry for 172.31.1.0/24
  Known via "bgp 65000", distance 20, metric 0
  Last update from 169.254.10.1 00:00:41 ago
```
6 prefixes received, state Established, and the Prod VPC subnet is back in the RIB via the correct next hop. Confirm from a branch host with `traceroute` that the path now transits CORE-R1 -> AWS again instead of the de-preferenced Azure-side backup path.
