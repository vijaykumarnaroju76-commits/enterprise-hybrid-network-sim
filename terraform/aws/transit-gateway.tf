# Transit Gateway with two separate route tables (Prod, Dev) so a Dev
# route can never propagate into Prod's table or vice versa — per
# documentation/cloud-networking.md section 1.2/1.3.

resource "aws_ec2_transit_gateway" "this" {
  description                    = "enterprise-hybrid-network-sim TGW"
  amazon_side_asn                = var.tgw_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = merge(var.tags, { Name = "hub-tgw" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id              = aws_vpc.prod.id
  subnet_ids          = [aws_subnet.prod_tgw_attach.id]
  tags                = merge(var.tags, { Name = "tgw-attach-prod" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id              = aws_vpc.dev.id
  subnet_ids          = [aws_subnet.dev_tgw_attach.id]
  tags                = merge(var.tags, { Name = "tgw-attach-dev" })
}

resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags                = merge(var.tags, { Name = "tgw-rt-prod" })
}

resource "aws_ec2_transit_gateway_route_table" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags                = merge(var.tags, { Name = "tgw-rt-dev" })
}

resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route_table_association" "dev" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

# Static route: each VPC's own CIDR into its own TGW route table.
resource "aws_ec2_transit_gateway_route" "prod_vpc" {
  destination_cidr_block        = var.prod_vpc_cidr
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route" "dev_vpc" {
  destination_cidr_block        = var.dev_vpc_cidr
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

# Route propagation from both VPN attachments into BOTH route tables is
# the deliberate design (each VPN needs to reach both Prod and Dev), but
# on-prem routes only ever come in as the 10.0.0.0/8 aggregate — see
# documentation/failure-scenarios/09-cloud-route-table-error.md for what
# happens when propagation like this is left disabled by mistake.
resource "aws_ec2_transit_gateway_route_table_propagation" "prod_from_vpn_primary" {
  transit_gateway_attachment_id  = aws_vpn_connection.primary.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_from_vpn_primary" {
  transit_gateway_attachment_id  = aws_vpn_connection.primary.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_from_vpn_backup" {
  transit_gateway_attachment_id  = aws_vpn_connection.backup.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dev_from_vpn_backup" {
  transit_gateway_attachment_id  = aws_vpn_connection.backup.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dev.id
}
