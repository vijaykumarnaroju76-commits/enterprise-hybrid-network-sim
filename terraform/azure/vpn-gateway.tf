# Azure VPN gateways and BGP peer definitions.
#
# Azure and the on-premises routers use DISTINCT BGP peering addresses.
# The Local Network Gateway bgp_peering_address is the ON-PREMISES BGP
# address. The Azure Virtual Network Gateway uses its own APIPA address.
#
# Primary: CORE-R2 <-> Azure Prod VNG
# Backup:  CORE-R1 <-> Azure Prod VNG
# Dev has its own VNG and primary connection to CORE-R2.

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

    peering_addresses {
      ip_configuration_name = "vgw-prod-ipconfig"
      apipa_addresses       = ["169.254.20.2"]
    }
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

    peering_addresses {
      ip_configuration_name = "vgw-dev-ipconfig"
      apipa_addresses       = ["169.254.21.2"]
    }
  }

  tags = var.tags
}

# Local Network Gateways describe the on-premises side.
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

resource "azurerm_local_network_gateway" "core_r2_dev" {
  name                = "lng-core-r2-dev"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = var.core_r2_public_ip
  address_space       = [var.onprem_aggregate_cidr]

  bgp_settings {
    asn                 = 65000
    bgp_peering_address = "169.254.21.1"
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "prod_primary" {
  name                       = "conn-prod-core-r2-primary"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.prod.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r2_primary.id
  shared_key                 = var.azure_vpn_psk_primary
  enable_bgp                 = true
  tags                       = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "dev_primary" {
  name                       = "conn-dev-core-r2-primary"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.dev.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r2_dev.id
  shared_key                 = var.azure_vpn_psk_primary
  enable_bgp                 = true
  tags                       = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "prod_backup" {
  name                       = "conn-prod-core-r1-backup"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.prod.id
  local_network_gateway_id   = azurerm_local_network_gateway.core_r1_backup.id
  shared_key                 = var.azure_vpn_psk_backup
  enable_bgp                 = true
  tags                       = var.tags
}
