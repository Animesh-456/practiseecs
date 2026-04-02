data "aws_subnets" "private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["private*"]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "tag:Name"
    values = ["public*"]
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = data.aws_subnets.public_subnets.ids[0]

  tags = {
    Name = "nat-gateway"
  }
}

data "aws_route_table" "private_route_table" {
  filter {
    name   = "tag:Name"
    values = ["private*"]
  }
}

resource "aws_route" "r" {
  route_table_id         = data.aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}