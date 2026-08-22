# One VPN Gateway per VNet (not a shared hub like AWS's Transit Gateway —
# see documentation/cloud-networking.md section 2.1 for why that asymmetry
# is deliberate). Prod's gateway is the primary path from CORE-R2; Dev's
# gateway also connects back to on-prem, matching the redundancy design in
# documentation/routing.md section 5.

resource "azurerm_public_ip" "prod_vgw" {
  name                = "pip-vgw-prod"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "prod" {
  name                = "vgw-prod"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw2"
  active_active       = false

  ip_configuration {
    name                          = "vgw-prod-ipconfig"
    public_ip_address_id          = azurerm_public_ip.prod_vgw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.prod_gateway.id
  }

  bgp_settings {
    asn = var.vpn_gateway_asn
  }

  tags = var.tags
}

resource "azurerm_public_ip" "dev_vgw" {
  name                = "pip-vgw-dev"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "dev" {
  name                = "vgw-dev"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false

  ip_configuration {
    name                          = "vgw-dev-ipconfig"
    public_ip_address_id          = azurerm_public_ip.dev_vgw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.dev_gateway.id
  }

  bgp_settings {
    asn = var.vpn_gateway_asn
  }

  tags = var.tags
}

# On-prem side of the tunnels: primary from CORE-R2, backup from CORE-R1,
# per architecture.md section 3.3.
resource "azurerm_local_network_gateway" "core_r2_primary" {
  name                = "lng-core-r2-primary"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = var.core_r2_public_ip
  address_space       = [var.onprem_aggregate_cidr]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = "169.254.20.1"
  }

  tags = var.tags
}

resource "azurerm_local_network_gateway" "core_r1_backup" {
  name                = "lng-core-r1-backup"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = var.core_r1_public_ip
  address_space       = [var.onprem_aggregate_cidr]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = "169.254.20.5"
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "prod_primary" {
  name                = "conn-prod-core-r2-primary"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.prod.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r2_primary.id
  shared_key                 = var.azure_vpn_psk_primary
  enable_bgp                 = true
  tags                        = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "dev_primary" {
  name                = "conn-dev-core-r2-primary"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.dev.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r2_primary.id
  shared_key                 = var.azure_vpn_psk_primary
  enable_bgp                 = true
  tags                        = var.tags
}

# Backup connection from CORE-R1, attached to the Prod gateway only —
# Dev traffic failing over through the same backup path as Prod during a
# CORE-R2 outage is an accepted simplification for this lab (see
# architecture.md section 1 redundancy model).
resource "azurerm_virtual_network_gateway_connection" "prod_backup" {
  name                = "conn-prod-core-r1-backup"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.prod.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r1_backup.id
  shared_key                 = var.azure_vpn_psk_backup
  enable_bgp                 = true
  tags                        = var.tags
}
