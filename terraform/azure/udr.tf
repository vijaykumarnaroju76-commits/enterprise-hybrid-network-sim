# User-Defined Routes — per documentation/cloud-networking.md section 2.2.
# GatewaySubnet deliberately has NO route table associated (Azure requires
# it stay on system routes); see
# documentation/failure-scenarios/09-cloud-route-table-error.md for what
# breaks when that rule is violated.

resource "azurerm_route_table" "prod_app" {
  name                = "rt-prod-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  route {
    name                   = "to-onprem"
    address_prefix         = var.onprem_aggregate_cidr
    next_hop_type          = "VirtualNetworkGateway"
  }
}

resource "azurerm_route_table" "prod_data" {
  name                = "rt-prod-data"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  route {
    name                   = "to-onprem"
    address_prefix         = var.onprem_aggregate_cidr
    next_hop_type          = "VirtualNetworkGateway"
  }
}

resource "azurerm_route_table" "dev_app" {
  name                = "rt-dev-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  route {
    name                   = "to-onprem"
    address_prefix         = var.onprem_aggregate_cidr
    next_hop_type          = "VirtualNetworkGateway"
  }
}

resource "azurerm_subnet_route_table_association" "prod_app" {
  subnet_id      = azurerm_subnet.prod_app.id
  route_table_id = azurerm_route_table.prod_app.id
}

resource "azurerm_subnet_route_table_association" "prod_data" {
  subnet_id      = azurerm_subnet.prod_data.id
  route_table_id = azurerm_route_table.prod_data.id
}

resource "azurerm_subnet_route_table_association" "dev_app" {
  subnet_id      = azurerm_subnet.dev_app.id
  route_table_id = azurerm_route_table.dev_app.id
}
