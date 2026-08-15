# Validation and Testing Guide

Comprehensive testing procedures to validate the enterprise hybrid network simulation.

## Pre-Testing Checklist

- [ ] All GNS3 devices are powered on and booted
- [ ] All interfaces show "up/up" status
- [ ] OSPF and BGP neighbors are established
- [ ] VPN tunnel is active
- [ ] AWS VPC is accessible
- [ ] No errors in device logs

## Test 1: OSPF Connectivity Validation

### Objective
Verify OSPF routing protocol is functioning correctly and routes are converging.

### Test Steps

**1. Verify OSPF Neighbors**
```bash
# On each site router
show ip ospf neighbor

# Expected Output:
# Neighbor ID     Pri   State           Dead Time   Address         Interface
# 2.2.2.2         128   FULL/BDR        35s         10.1.1.2        Fa0/0
# 3.3.3.3         128   FULL/DR         35s         10.1.2.3        Fa0/1
```

**2. Check OSPF Interface Status**
```bash
# Verify all OSPF interfaces are active
show ip ospf interface brief

# Expected: All configured interfaces show up
```

**3. Verify Learned Routes**
```bash
# Check routes learned from OSPF
show ip route ospf

# Expected: All site networks visible
# O       10.2.1.0/24 [110/2] via 10.1.1.2, 00:05:23, Fa0/0
# O       10.3.1.0/24 [110/3] via 10.1.2.3, 00:05:23, Fa0/1
```

**4. Verify OSPF Database**
```bash
# Check OSPF Link State Database
show ip ospf database

# Check for Router LSAs from all sites
show ip ospf database router
```

**5. Test OSPF Convergence**
```bash
# Simulate link failure and measure convergence
# Shutdown interface on Site1
configure terminal
interface Fa0/0
 shutdown
end

# On Site2, measure how quickly alternate route appears
# Re-enable after 30 seconds
configure terminal
interface Fa0/0
 no shutdown
end

# Expected: Route converges in < 1 second
```

### Pass/Fail Criteria
- ✅ All OSPF neighbors show FULL state
- ✅ All site networks learned via OSPF
- ✅ Convergence time < 1 second
- ✅ No OSPF error messages in logs

---

## Test 2: BGP Configuration Validation

### Objective
Verify BGP routing protocol is operational and route exchange with AWS is working.

### Test Steps

**1. Check BGP Neighbors Status**
```bash
# Verify all BGP neighbors are established
show ip bgp summary

# Expected:
# Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State
# 203.0.113.1     4 64512    150     152       45    0    0 00:20:30 Established
```

**2. Verify BGP Routes**
```bash
# Check BGP routing table
show ip bgp

# Expected:
#    Network          Next Hop            Metric LocPrf Weight Path
#  * 10.0.0.0/8       203.0.113.1              0             0 64512 i
#  * 172.31.0.0/16    203.0.113.1              0             0 64512 i
```

**3. Verify Advertised Routes**
```bash
# Check what we're advertising to AWS
show ip bgp neighbors 203.0.113.1 advertised-routes

# Expected: All site subnets and aggregates listed
```

**4. Verify Received Routes**
```bash
# Check what we're receiving from AWS
show ip bgp neighbors 203.0.113.1 received-routes

# Expected: AWS VPC CIDR blocks
```

**5. Check BGP Dampening**
```bash
# Verify route flap dampening is working
show ip bgp dampening flap-statistics
```

### Pass/Fail Criteria
- ✅ BGP neighbor state is "Established"
- ✅ All site routes are advertised to AWS
- ✅ AWS VPC routes are received
- ✅ No route flaps or oscillation

---

## Test 3: VPN Tunnel Validation

### Objective
Verify IPSec VPN tunnel to AWS is secure and operational.

### Test Steps

**1. Check Tunnel Interface Status**
```bash
# Verify tunnel interface is up
show interface tunnel 0

# Expected:
# Tunnel0 is up, line protocol is up
# Hardware is Tunnel
# MTU 1436 bytes, BW 100 Kbit/sec
```

**2. Verify Crypto Session**
```bash
# Check IPSec crypto sessions
show crypto session

# Expected:
# Crypto session current status
# Interface: Tunnel0
# Session status: UP-ACTIVE
```

**3. Check IPSec SA (Security Associations)**
```bash
# Verify IPSec transform sets are active
show crypto ipsec sa

# Expected:
# interface: Tunnel0
#   Inbound:  #pkts decaps: 1000, #pkts decrypt: 1000, #pkts verify: 1000
#   Outbound: #pkts encaps: 1050, #pkts encrypt: 1050, #pkts sign: 1050
```

**4. Monitor IKE Exchanges**
```bash
# Check IKEv2 exchanges
show crypto ikev2 sa

# Expected:
#  IPv4 Crypto IKEv2  SA
#  Tunnel-id Local                Remote             fqdn fqdn state
#  1.1.1.1   10.1.1.1             203.0.113.1              ESTABLISHED
```

**5. Verify MTU Settings**
```bash
# Check tunnel MTU for proper packet handling
show interface tunnel 0 | include MTU

# Expected: MTU 1436 (accounting for IPSec overhead)
```

### Pass/Fail Criteria
- ✅ Tunnel interface status: UP
- ✅ Crypto session status: UP-ACTIVE
- ✅ Security Associations established
- ✅ No IPSec errors in logs
- ✅ MTU correctly configured

---

## Test 4: End-to-End Connectivity Testing

### Objective
Validate complete traffic flow from on-premises to AWS.

### Test Steps

**1. Ping from Site 1 to AWS Resources**
```bash
# Ping AWS VPC gateway
ping 172.31.0.1

# Expected:
# Success rate is 100 percent (4/4), round-trip min/avg/max = 50/55/60 ms
```

**2. Ping from Site 2 to AWS**
```bash
# Verify path through OSPF and BGP
ping 172.31.1.1 source 10.2.1.1

# Expected: Successful pings through tunnel
```

**3. Test Traceroute to AWS**
```bash
# Verify complete path
traceroute 172.31.0.1

# Expected path:
# 1  10.1.1.2 (Site1 neighbor)
# 2  192.168.1.2 (VPN tunnel)
# 3  172.31.0.1 (AWS VPC)
```

**4. Verify Return Path**
```bash
# From AWS instance, ping Site3
# (Execute on AWS EC2 instance)
ping 10.3.1.1

# Expected: Successful response from Site3
```

**5. Test Extended Ping**
```bash
# Long-term connectivity test
ping -c 1000 172.31.0.1

# Expected: 100% success rate with consistent latency
```

### Pass/Fail Criteria
- ✅ All pings successful to AWS
- ✅ Consistent round-trip time (no spikes)
- ✅ Return path verified
- ✅ No packet loss

---

## Test 5: Performance and Load Testing

### Objective
Verify network performance under load.

### Test Steps

**1. Baseline Throughput Test**
```bash
# On Site1, start iperf server
iperf -s

# On Site4, start iperf client to AWS
iperf -c 172.31.0.100 -t 60

# Expected: Stable throughput, no packet loss
```

**2. VPN Tunnel Throughput**
```bash
# Test tunnel-specific throughput
# Expected: > 100 Mbps (depends on underlying network)
```

**3. OSPF Convergence Under Load**
```bash
# While running traffic:
# 1. Shutdown an interface
# 2. Measure failover time
# 3. Re-enable interface

# Expected: Failover < 2 seconds with minimal packet loss
```

**4. BGP Route Flap Testing**
```bash
# Withdraw and re-advertise routes
configure terminal
router bgp 65000
 address-family ipv4
  no network 10.1.1.0
 exit-address-family
end

# Wait 5 seconds, then re-add
configure terminal
router bgp 65000
 address-family ipv4
  network 10.1.1.0 mask 255.255.255.0
 exit-address-family
end

# Verify route converges correctly
show ip bgp
```

### Pass/Fail Criteria
- ✅ Sustained throughput > 100 Mbps
- ✅ No packet loss during load
- ✅ Convergence time acceptable
- ✅ No route oscillation

---

## Test 6: Failover and Redundancy Testing

### Objective
Verify network behavior during link failures.

### Test Steps

**1. Link Failure Test**
```bash
# Simulate Site1-Site2 link failure
configure terminal
interface Fa0/0
 shutdown
end

# On Site2, verify:
show ip ospf neighbor
show ip route ospf

# Expected: Traffic reroutes through alternate path (Site1->Site3->Site2)
```

**2. Measure Failover Time**
```bash
# Start continuous ping before shutdown
ping 10.2.1.1 (repeat forever)

# Shutdown link and note:
# - Time until first timeout
# - Time to recovery

# Expected: < 1 second convergence
```

**3. VPN Tunnel Redundancy**
```bash
# Shut down primary tunnel
configure terminal
interface tunnel 0
 shutdown
end

# Verify:
show ip route
show crypto session

# Expected: Routes switch to alternate path or failover tunnel
```

**4. Link Recovery**
```bash
# Re-enable failed link
configure terminal
interface Fa0/0
 no shutdown
end

# Verify convergence and route optimization
# Expected: Original path used again within 5 seconds
```

### Pass/Fail Criteria
- ✅ Failover triggers automatically
- ✅ Failover time < 1 second
- ✅ No routing loops
- ✅ Recovery smooth with no routing oscillation

---

## Test 7: Security Validation

### Objective
Verify VPN encryption and authentication are working.

### Test Steps

**1. Capture and Verify Encryption**
```bash
# Capture packets on tunnel interface
# Verify payloads are encrypted (not readable plaintext)

show crypto ipsec sa
# Look for: #pkts encrypt != 0
```

**2. Verify Pre-shared Key Authentication**
```bash
# Attempt to connect with wrong PSK
# Expected: Connection fails

# Verify correct PSK
show crypto ikev2 sa detail
# Should show authentication successful
```

**3. Check ACL Rules**
```bash
# Verify traffic is properly classified
show access-lists

# Verify only intended traffic goes through tunnel
show crypto ipsec sa | include encrypt
```

**4. Monitor Failed Decryption**
```bash
# Check for decryption errors
show crypto ipsec sa | include decrypt

# Expected: All decryptions successful (no errors)
```

### Pass/Fail Criteria
- ✅ All tunnel traffic is encrypted
- ✅ Authentication succeeds with correct PSK
- ✅ No decryption errors
- ✅ Only authorized traffic through tunnel

---

## Test 8: Logging and Monitoring

### Objective
Verify logging and monitoring capabilities.

### Test Steps

**1. Enable Debug Logging**
```bash
# Enable appropriate debug commands
debug ip ospf adj
debug ip ospf events
debug ip bgp keepalives
debug crypto ipsec

# Observe events for 2 minutes
# Expected: Clean, informative logs
```

**2. Check Syslog**
```bash
# Verify syslog is operational
show logging

# Expected: Configured syslog server
```

**3. Monitor Interface Statistics**
```bash
# Check interface counters
show interfaces accounting

# Expected: No errors, resets, or collisions
```

**4. Review Error Logs**
```bash
# Check for any error conditions
show log
# OR
show system

# Expected: Minimal errors, normal operation messages
```

### Pass/Fail Criteria
- ✅ Logging is active and detailed
- ✅ No critical errors in logs
- ✅ Interface statistics normal
- ✅ Syslog operational

---

## Automated Testing Script

Use provided testing script:
```bash
# Run comprehensive validation
./scripts/vpn-tunnel-test.sh

# Run route verification
./scripts/route-verification.sh

# Perform traffic analysis
./scripts/traffic-analysis.sh
```

## Troubleshooting Test Failures

| Test | Failure | Resolution |
|------|---------|-----------|
| OSPF Neighbors | Not forming | Verify interfaces up, check IP addresses, verify area config |
| BGP Routes | Not advertising | Check network statements, verify BGP is enabled |
| VPN Tunnel | Down | Verify PSK, check transform sets, verify IP connectivity |
| Ping Fails | No response | Check routing table, verify ACLs, check interface status |
| High Latency | Slow response | Check interface utilization, verify no packet drops |

## Test Report Template

```
TEST RUN: [Date]
TESTER: [Name]

OSPF Connectivity:     [ PASS / FAIL ]
BGP Configuration:     [ PASS / FAIL ]
VPN Tunnel Status:     [ PASS / FAIL ]
End-to-End Traffic:    [ PASS / FAIL ]
Performance:           [ PASS / FAIL ]
Failover/Redundancy:   [ PASS / FAIL ]
Security:              [ PASS / FAIL ]
Logging/Monitoring:    [ PASS / FAIL ]

OVERALL RESULT:        [ PASS / FAIL ]

Notes:
[Any observations or issues]
```

---

**Last Updated:** August 2026
