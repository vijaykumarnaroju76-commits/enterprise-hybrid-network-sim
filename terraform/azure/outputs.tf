output "prod_vnet_id" {
  value = azurerm_virtual_network.prod.id
}

output "dev_vnet_id" {
  value = azurerm_virtual_network.dev.id
}

output "prod_vgw_public_ip" {
  description = "Should match architecture.md's Azure primary tunnel endpoint, 203.0.113.10."
  value       = azurerm_public_ip.prod_vgw.ip_address
}

output "dev_vgw_public_ip" {
  value = azurerm_public_ip.dev_vgw.ip_address
}

output "vpn_gateway_asn" {
  value = var.vpn_gateway_asn
}
