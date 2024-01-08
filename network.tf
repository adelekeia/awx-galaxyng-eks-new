resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_internet_gateway" "eks_igw" {
  depends_on = [ aws_vpc.eks_vpc ]
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_subnet" "eks_subnet" {
  depends_on = [ aws_vpc.eks_vpc ]
  count = 3  # Create 3 subnets
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
}

resource "aws_route_table_association" "eks_rta" {
  count = length(aws_subnet.eks_subnet)

  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.eks_rt.id
}

data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_db_subnet_group" "postgres" {
  name       = "awx-postgres-2"
  subnet_ids = aws_subnet.eks_subnet[*].id
}