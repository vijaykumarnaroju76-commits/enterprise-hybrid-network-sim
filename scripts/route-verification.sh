#!/bin/bash

# Route Verification Script
# Verifies OSPF and BGP route propagation

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Route Verification Script ===${NC}"
echo ""

# Expected routes for 4-site topology
SITE1_NETS="10.1.1.0/24 10.1.2.0/24"
SITE2_NETS="10.2.1.0/24 10.2.2.0/24"
SITE3_NETS="10.3.1.0/24 10.3.2.0/24"
SITE4_NETS="10.4.1.0/24 10.4.2.0/24"
AWS_NETS="172.31.0.0/16"

echo -e "${YELLOW}Expected Route Summary:${NC}"
echo "Site1 Networks: $SITE1_NETS"
echo "Site2 Networks: $SITE2_NETS"
echo "Site3 Networks: $SITE3_NETS"
echo "Site4 Networks: $SITE4_NETS"
echo "AWS VPC: $AWS_NETS"
echo ""

echo -e "${YELLOW}Route Verification Tasks:${NC}"
echo ""

echo "1. Verify OSPF Routes Learned"
echo "   Command: show ip route ospf"
echo "   Expected: All site networks visible via OSPF"
echo ""

echo "2. Verify BGP Routes Received"
echo "   Command: show ip bgp"
echo "   Expected: AWS VPC routes visible"
echo ""

echo "3. Check Route Convergence"
echo "   Command: show ip route | include E or O"
echo "   Expected: Sub-second convergence time"
echo ""

echo "4. Verify Aggregate Routes"
echo "   Command: show ip bgp summary"
echo "   Expected: 10.0.0.0/8 summarized"
echo ""

echo "5. Check For Routing Loops"
echo "   Command: traceroute 10.2.1.1"
echo "   Expected: No loops, direct or via alternate path"
echo ""

echo -e "${GREEN}=== Verification Commands Reference ===${NC}"
echo ""
echo "OSPF Verification:"
echo "  - show ip ospf neighbor"
echo "  - show ip ospf interface brief"
echo "  - show ip route ospf"
echo "  - show ip ospf database"
echo ""

echo "BGP Verification:"
echo "  - show ip bgp summary"
echo "  - show ip bgp"
echo "  - show ip bgp neighbors"
echo "  - show ip bgp neighbors X.X.X.X received-routes"
echo "  - show ip bgp neighbors X.X.X.X advertised-routes"
echo ""

echo "Route Table Analysis:"
echo "  - show ip route"
echo "  - show ip route summary"
echo "  - show ip route X.X.X.X"
echo ""

echo "Troubleshooting:"
echo "  - show ip route unreachable"
echo "  - show ip route vrf all"
echo "  - clear ip route *"
echo "  - debug ip routing"
echo ""

echo -e "${YELLOW}=== Route Verification Complete ===${NC}"
echo "Please run the referenced commands on your routers for verification"
exit 0
