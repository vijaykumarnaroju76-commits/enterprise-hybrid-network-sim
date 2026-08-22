# Prod VPC — 172.31.0.0/16, per documentation/cloud-networking.md section 1.1

resource "aws_vpc" "prod" {
  cidr_block           = var.prod_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "prod-vpc" })
}

resource "aws_subnet" "prod_tgw_attach" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_vpc_cidr, 8, 0) # 172.31.0.0/24
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "prod-tgw-attach" })
}

resource "aws_subnet" "prod_app" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_vpc_cidr, 8, 1) # 172.31.1.0/24
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "prod-app" })
}

resource "aws_subnet" "prod_data" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_vpc_cidr, 8, 2) # 172.31.2.0/24
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "prod-data" })
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Route table: on-prem aggregate via the TGW attachment, nothing to the Dev VPC.
resource "aws_route_table" "prod" {
  vpc_id = aws_vpc.prod.id
  tags   = merge(var.tags, { Name = "prod-rt" })
}

resource "aws_route" "prod_to_onprem" {
  route_table_id         = aws_route_table.prod.id
  destination_cidr_block = var.onprem_aggregate_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.prod]
}

resource "aws_route_table_association" "prod_tgw_attach" {
  subnet_id      = aws_subnet.prod_tgw_attach.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_route_table_association" "prod_app" {
  subnet_id      = aws_subnet.prod_app.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_route_table_association" "prod_data" {
  subnet_id      = aws_subnet.prod_data.id
  route_table_id = aws_route_table.prod.id
}
