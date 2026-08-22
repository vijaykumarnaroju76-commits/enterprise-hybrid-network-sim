output "prod_vpc_id" {
  value = aws_vpc.prod.id
}

output "dev_vpc_id" {
  value = aws_vpc.dev.id
}

output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "vpn_primary_outside_ip_address_1" {
  description = "AWS-side tunnel 1 endpoint for the primary (CORE-R1) VPN — should match architecture.md's 203.0.113.1."
  value       = aws_vpn_connection.primary.tunnel1_address
}

output "vpn_backup_outside_ip_address_1" {
  description = "AWS-side tunnel 1 endpoint for the backup (CORE-R2) VPN — should match architecture.md's 203.0.113.2."
  value       = aws_vpn_connection.backup.tunnel1_address
}

output "vpn_primary_bgp_asn" {
  value = aws_customer_gateway.core_r1.bgp_asn
}
