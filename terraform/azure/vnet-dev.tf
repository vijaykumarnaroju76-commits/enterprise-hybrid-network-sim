# Dev VNet — 172.33.0.0/16, per documentation/cloud-networking.md section 2.1.
# Intentionally separate address space and separate VPN Gateway from Prod;
# no peering resource between the two VNets anywhere in this module.

resource "azurerm_virtual_network" "dev" {
  name                = "vnet-dev"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.dev_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "dev_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = [cidrsubnet(var.dev_vnet_cidr, 11, 0)] # 172.33.0.0/27
}

resource "azurerm_subnet" "dev_app" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = [cidrsubnet(var.dev_vnet_cidr, 8, 1)] # 172.33.1.0/24
}

resource "azurerm_network_security_group" "dev_app" {
  name                = "nsg-dev-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-OnPrem"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.onprem_aggregate_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev_app" {
  subnet_id                 = azurerm_subnet.dev_app.id
  network_security_group_id = azurerm_network_security_group.dev_app.id
}
