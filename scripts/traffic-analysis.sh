#!/bin/bash

# Traffic Analysis Script
# Analyzes VPN and network traffic patterns

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Network Traffic Analysis ===${NC}"
echo ""

echo -e "${YELLOW}Traffic Analysis Points:${NC}"
echo ""

echo "1. Interface Statistics"
echo "   Command: show interface"
echo "   Monitor: Input/output packets, errors, dropped"
echo "   Healthy: No errors or drops under normal load"
echo ""

echo "2. VPN Tunnel Throughput"
echo "   Command: show crypto ipsec sa"
echo "   Monitor: #pkts encrypt/decrypt"
echo "   Healthy: Consistent traffic in both directions"
echo ""

echo "3. BGP Traffic Analysis"
echo "   Command: show ip bgp"
echo "   Monitor: Route updates, withdrawals"
echo "   Healthy: Stable after convergence"
echo ""

echo "4. OSPF Neighbor Traffic"
echo "   Command: show ip ospf neighbor detail"
echo "   Monitor: Hellos sent/received"
echo "   Healthy: 0 hellos dropped"
echo ""

echo "5. Queue Statistics"
echo "   Command: show queue interface tunnel 0"
echo "   Monitor: Queue depth, drops"
echo "   Healthy: No queue drops"
echo ""

echo -e "${YELLOW}Performance Monitoring Commands:${NC}"
echo ""

echo "Real-time Interface Monitoring:"
echo "  - terminal monitor"
echo "  - show ip route (continuously updated)"
echo ""

echo "Traffic Rate Monitoring:"
echo "  - show interfaces tunnel 0"
echo "  - (repeat command in intervals)"
echo ""

echo "CPU/Memory Monitoring:"
echo "  - show processes"
echo "  - show memory"
echo ""

echo "Crypto Statistics:"
echo "  - show crypto engine connections active"
echo "  - show crypto engine statistics"
echo ""

echo -e "${YELLOW}Traffic Capture (Packet Sniffer):${NC}"
echo ""
echo "To capture traffic for analysis:"
echo "  1. monitor capture buffer BUFFER max-size 1500 max-packets 1000"
echo "  2. monitor capture point ip process POINT interface tunnel 0 both"
echo "  3. monitor capture point associate POINT BUFFER"
echo "  4. monitor capture point start POINT"
echo "  5. (wait for traffic)"
echo "  6. monitor capture point stop POINT"
echo "  7. show monitor capture buffer BUFFER dump"
echo ""

echo -e "${YELLOW}Baseline Metrics:${NC}"
echo ""
echo "Establish these baselines for comparison:"
echo "  - VPN Tunnel Throughput: ??? Mbps"
echo "  - Average Latency: ??? ms"
echo "  - Packet Loss Rate: ??? %"
echo "  - CPU Utilization: ??? %"
echo "  - Memory Utilization: ??? %"
echo "  - BGP Route Count: ???"
echo "  - OSPF Neighbor Count: ???"
echo ""

echo -e "${YELLOW}Anomaly Detection:${NC}"
echo ""
echo "Alert if:"
echo "  - Latency increases > 50% from baseline"
echo "  - Packet loss detected on any link"
echo "  - CPU usage > 80%"
echo "  - Memory usage > 85%"
echo "  - BGP/OSPF neighbors drop"
echo "  - VPN tunnel goes down"
echo "  - Cryptographic errors occur"
echo ""

echo -e "${GREEN}=== Traffic Analysis Complete ===${NC}"
echo "Configure continuous monitoring based on above parameters"
exit 0
