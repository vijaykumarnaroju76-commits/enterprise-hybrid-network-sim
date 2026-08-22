# Dev VPC — 172.30.0.0/16, per documentation/cloud-networking.md section 1.1.
# Intentionally separate from Prod: no route between the two VPCs anywhere
# in this module, enforced at the TGW route table layer in transit-gateway.tf.

resource "aws_vpc" "dev" {
  cidr_block           = var.dev_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "dev-vpc" })
}

resource "aws_subnet" "dev_tgw_attach" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = cidrsubnet(var.dev_vpc_cidr, 8, 0) # 172.30.0.0/24
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "dev-tgw-attach" })
}

resource "aws_subnet" "dev_app" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = cidrsubnet(var.dev_vpc_cidr, 8, 1) # 172.30.1.0/24
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "dev-app" })
}

resource "aws_route_table" "dev" {
  vpc_id = aws_vpc.dev.id
  tags   = merge(var.tags, { Name = "dev-rt" })
}

resource "aws_route" "dev_to_onprem" {
  route_table_id         = aws_route_table.dev.id
  destination_cidr_block = var.onprem_aggregate_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on              = [aws_ec2_transit_gateway_vpc_attachment.dev]
}

resource "aws_route_table_association" "dev_tgw_attach" {
  subnet_id      = aws_subnet.dev_tgw_attach.id
  route_table_id = aws_route_table.dev.id
}

resource "aws_route_table_association" "dev_app" {
  subnet_id      = aws_subnet.dev_app.id
  route_table_id = aws_route_table.dev.id
}
