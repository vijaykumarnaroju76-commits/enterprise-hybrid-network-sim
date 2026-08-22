# Prod VNet — 172.32.0.0/16, per documentation/cloud-networking.md section 2.1.

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "prod" {
  name                = "vnet-prod"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.prod_vnet_cidr]
  tags                = var.tags
}

# Name is fixed by Azure — must be exactly "GatewaySubnet".
resource "azurerm_subnet" "prod_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = [cidrsubnet(var.prod_vnet_cidr, 11, 0)] # 172.32.0.0/27
}

resource "azurerm_subnet" "prod_app" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = [cidrsubnet(var.prod_vnet_cidr, 8, 1)] # 172.32.1.0/24
}

resource "azurerm_subnet" "prod_data" {
  name                 = "data"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = [cidrsubnet(var.prod_vnet_cidr, 8, 2)] # 172.32.2.0/24
}

resource "azurerm_network_security_group" "prod_app" {
  name                = "nsg-prod-app"
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

resource "azurerm_network_security_group" "prod_data" {
  name                = "nsg-prod-data"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-App-Tier"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.prod_app.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "prod_app" {
  subnet_id                 = azurerm_subnet.prod_app.id
  network_security_group_id = azurerm_network_security_group.prod_app.id
}

resource "azurerm_subnet_network_security_group_association" "prod_data" {
  subnet_id                 = azurerm_subnet.prod_data.id
  network_security_group_id = azurerm_network_security_group.prod_data.id
}
