# Troubleshooting Guide

## Common Issues and Solutions

### OSPF Issues

#### Problem: OSPF Neighbors Not Forming
**Symptoms:**
- `show ip ospf neighbor` returns empty
- Routers not exchanging Hello packets
- Persistent "EXSTART/EXSTART" state

**Diagnosis:**
```bash
show ip ospf interface brief
show ip ospf neighbor detail
debug ip ospf adj
```

**Solutions:**
1. Verify interfaces are up: `show interface fa0/0`
2. Check IP addresses match subnet: `show ip interface brief`
3. Verify OSPF is enabled on interface: `show ip ospf interface`
4. Check network statement: `show run | include network`
5. Verify hello/dead timers match: `show ip ospf interface fa0/0`

#### Problem: OSPF Routes Not Learning
**Symptoms:**
- Routes from other sites not appearing in routing table
- `show ip route ospf` shows no routes

**Solutions:**
1. Verify neighbors are FULL state
2. Check OSPF database: `show ip ospf database`
3. Verify route filter policies: `show route-map`
4. Check access lists: `show access-lists`
5. Enable debug: `debug ip ospf database`

#### Problem: High OSPF Convergence Time
**Symptoms:**
- Routes take > 5 seconds to converge after topology change
- Intermittent connectivity issues

**Solutions:**
1. Lower hello interval: `ip ospf hello-interval 3`
2. Lower dead interval: `ip ospf dead-interval 10`
3. Optimize cost values: `auto-cost reference-bandwidth 1000`
4. Enable BFD for faster failure detection

### BGP Issues

#### Problem: BGP Neighbors Not Establishing
**Symptoms:**
- BGP neighbor state shows "Idle" or "Active"
- `show ip bgp summary` shows 0 for MsgRcvd/MsgSent

**Diagnosis:**
```bash
show ip bgp neighbors 203.0.113.1
debug ip bgp keepalives
debug ip bgp updates
```

**Solutions:**
1. Verify TCP port 179 connectivity: `telnet 203.0.113.1 179`
2. Check neighbor IP address: `show run | include neighbor`
3. Verify local AS number: `show ip bgp summary | include local`
4. Check firewall/ACLs blocking traffic
5. Verify router ID is unique: `show ip bgp`

#### Problem: BGP Routes Not Advertising
**Symptoms:**
- Routes appear in local BGP table but not sent to neighbors
- `show ip bgp neighbors X.X.X.X advertised-routes` is empty

**Solutions:**
1. Check network statements in BGP config
2. Verify aggregate-address configuration
3. Check route-map filters: `show route-map`
4. Review prefix-lists: `show ip prefix-list`
5. Enable soft reconfiguration: `neighbor X.X.X.X soft-reconfiguration inbound`

#### Problem: BGP Route Flapping
**Symptoms:**
- Routes constantly appearing/disappearing
- High prefix flap-count in `show ip bgp dampening`

**Solutions:**
1. Stabilize underlying IGP (OSPF)
2. Increase BGP timers: `neighbor X.X.X.X timers 5 15`
3. Enable route dampening: `bgp dampening`
4. Check for route oscillation: `show ip bgp route-map`
5. Verify network stability

### VPN Tunnel Issues

#### Problem: VPN Tunnel Status Down
**Symptoms:**
- `show interface tunnel 0` shows "down"
- `show crypto session` shows no active sessions

**Diagnosis:**
```bash
show crypto session
show crypto ikev2 sa
show crypto ipsec sa
debug crypto ikev2
```

**Solutions:**
1. Verify public IP reachability: `ping 203.0.113.1`
2. Check pre-shared key matches: Compare on both ends
3. Verify IKEv2 proposal compatibility
4. Check transform set configuration
5. Verify ACLs permit tunnel traffic

#### Problem: VPN Tunnel Up But No Traffic
**Symptoms:**
- Tunnel interface shows up
- Cannot ping through tunnel
- `show crypto ipsec sa` shows no traffic

**Solutions:**
1. Check routing to tunnel destination: `show ip route`
2. Verify ACLs for tunnel traffic
3. Check MTU settings: `show interface tunnel 0 | include MTU`
4. Verify phase 2 transform sets match
5. Check route-map policies: `show route-map`

#### Problem: High VPN Tunnel Latency
**Symptoms:**
- Ping through tunnel shows 500ms+ latency
- Throughput is low

**Solutions:**
1. Check underlying link utilization
2. Enable QoS for tunnel traffic
3. Verify encryption algorithm not CPU-bound
4. Check for packet fragmentation/retransmission
5. Monitor device CPU/memory: `show processes`

### Interface Issues

#### Problem: Interface Flapping
**Symptoms:**
- Interface repeatedly goes up/down
- Repeated OSPF/BGP resets

**Solutions:**
1. Check cable connections (physical only in lab)
2. Verify MTU settings match on both ends
3. Disable speed/duplex auto-negotiation
4. Check for CRC errors: `show interface fa0/0`
5. Review interface configuration for errors

#### Problem: No Connectivity on Interface
**Symptoms:**
- Interface shows up but no traffic
- Cannot ping across link

**Solutions:**
1. Verify IP address: `show ip interface brief`
2. Check subnet mask: `show ip interface fa0/0 detailed`
3. Verify no access lists blocking traffic
4. Check for IP address conflicts: `arp -a`
5. Test connectivity to directly connected device

### Routing Issues

#### Problem: Routing Loop
**Symptoms:**
- Traceroute shows same router multiple times
- TTL exceeded errors
- High CPU utilization

**Solutions:**
1. Check BGP ASN configuration
2. Verify no duplicate router IDs
3. Review routing policies and filters
4. Check for misconfigured static routes
5. Verify network masks are correct

#### Problem: Asymmetric Routing
**Symptoms:**
- Traffic flows one way but not both
- Traceroute shows different paths

**Solutions:**
1. Verify reverse path exists
2. Check BGP route advertisements
3. Review routing policies on both routers
4. Verify static routes configured symmetrically
5. Check for ACLs blocking return traffic

### AWS VPN Issues

#### Problem: VPN Connection Status Degraded
**Symptoms:**
- AWS console shows tunnel down
- BGP session unstable with AWS

**Solutions:**
1. Verify Site-to-Site VPN connection settings
2. Download and reapply customer gateway configuration
3. Check AWS side: VPC route tables
4. Verify NAT not interfering with traffic
5. Check AWS security groups and NACLs

#### Problem: AWS Routes Not Received
**Symptoms:**
- BGP neighbors up but no AWS prefixes received
- Cannot reach AWS VPC subnets

**Solutions:**
1. Check route propagation enabled: AWS console
2. Verify BGP neighbor address on AWS side
3. Check AWS route table policies
4. Verify CIDR blocks are advertised from AWS
5. Review route table entries in AWS

## Performance Optimization

### Improve Convergence Time
```bash
! OSPF
router ospf 1
  timers throttle spf 50 100 5000
  timers throttle lsa 50 100 5000

! Interface-specific
interface fa0/0
  ip ospf hello-interval 3
  ip ospf dead-interval 10
  ip ospf retransmit-interval 5
```

### Optimize BGP
```bash
router bgp 65000
  timers bgp 3 9
  timers connect 10
  neighbor X.X.X.X timers 3 9
```

### Reduce VPN Latency
```bash
interface tunnel 0
  bandwidth 1000000
  priority-group 1
  no ip redirects
  no ip unreachables
```

## Monitoring Commands

### Real-time Monitoring
```bash
# Watch OSPF adjacencies
term mon
show ip ospf neighbor
q (exit)

# Watch BGP routes
term mon
show ip bgp
q

# Watch routing table
term mon
show ip route
q
```

### Log Analysis
```bash
# Check for errors
show log | include ERROR
show log | include WARNING

# Check recent activity
show log | last 50

# Clear logs (for fresh start)
clear log
```

## Reset Procedures

### Clear OSPF
```bash
clear ip ospf process
! Wait for neighbors to re-establish
```

### Clear BGP
```bash
clear ip bgp 203.0.113.1
clear ip bgp * soft
```

### Reset VPN
```bash
clear crypto session all
clear crypto ikev2 sa
```

---

**Last Updated:** August 2026
