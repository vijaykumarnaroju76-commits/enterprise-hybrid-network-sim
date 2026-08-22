# AWS Site-to-Site VPN connections into the Transit Gateway.
#
# Each aws_vpn_connection creates TWO AWS-managed IPsec tunnels for HA.
# Therefore this design has:
#   - primary VPN connection: CORE-R1 <-> AWS TGW, 2 tunnels
#   - backup VPN connection:  CORE-R2 <-> AWS TGW, 2 tunnels
#
# AWS tunnel inside CIDRs are explicitly assigned so Terraform, router
# configuration, and documentation can use the same deterministic values.

resource "aws_customer_gateway" "core_r1" {
  bgp_asn    = 65000
  ip_address = var.core_r1_public_ip
  type       = "ipsec.1"

  tags = merge(var.tags, { Name = "cgw-core-r1" })
}

resource "aws_customer_gateway" "core_r2" {
  bgp_asn    = 65000
  ip_address = var.core_r2_public_ip
  type       = "ipsec.1"

  tags = merge(var.tags, { Name = "cgw-core-r2" })
}

resource "aws_vpn_connection" "primary" {
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  customer_gateway_id = aws_customer_gateway.core_r1.id
  type                = "ipsec.1"
  static_routes_only  = false

  # AWS reserves two addresses in each /30; Terraform/AWS uses these
  # deterministic inside networks for BGP over the two redundant tunnels.
  tunnel1_inside_cidr = "169.254.10.0/30"
  tunnel2_inside_cidr = "169.254.10.4/30"

  tunnel1_preshared_key = var.aws_vpn_psk_primary
  tunnel2_preshared_key = var.aws_vpn_psk_primary

  tags = merge(var.tags, { Name = "vpn-primary-core-r1" })
}

resource "aws_vpn_connection" "backup" {
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  customer_gateway_id = aws_customer_gateway.core_r2.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr = "169.254.10.8/30"
  tunnel2_inside_cidr = "169.254.10.12/30"

  tunnel1_preshared_key = var.aws_vpn_psk_backup
  tunnel2_preshared_key = var.aws_vpn_psk_backup

  tags = merge(var.tags, { Name = "vpn-backup-core-r2" })
}
