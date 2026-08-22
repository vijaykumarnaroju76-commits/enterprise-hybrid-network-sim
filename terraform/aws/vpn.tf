# Two Site-to-Site VPN connections into the Transit Gateway — primary from
# CORE-R1, backup from CORE-R2 — per documentation/architecture.md section
# 3.3 and documentation/routing.md section 2/5.

resource "aws_customer_gateway" "core_r1" {
  bgp_asn    = 65000
  ip_address = var.core_r1_public_ip
  type       = "ipsec.1"
  tags       = merge(var.tags, { Name = "cgw-core-r1" })
}

resource "aws_customer_gateway" "core_r2" {
  bgp_asn    = 65000
  ip_address = var.core_r2_public_ip
  type       = "ipsec.1"
  tags       = merge(var.tags, { Name = "cgw-core-r2" })
}

resource "aws_vpn_connection" "primary" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  customer_gateway_id = aws_customer_gateway.core_r1.id
  type                = "ipsec.1"
  static_routes_only  = false # BGP-based, matches routing.md's dynamic eBGP design

  tunnel1_preshared_key = var.aws_vpn_psk_primary
  tunnel2_preshared_key = var.aws_vpn_psk_primary

  tags = merge(var.tags, { Name = "vpn-primary-core-r1" })
}

resource "aws_vpn_connection" "backup" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  customer_gateway_id = aws_customer_gateway.core_r2.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_preshared_key = var.aws_vpn_psk_backup
  tunnel2_preshared_key = var.aws_vpn_psk_backup

  tags = merge(var.tags, { Name = "vpn-backup-core-r2" })
}
