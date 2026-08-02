# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-techstock"
  }
}

# Definição das Zonas de Disponibilidade
# Learner Lab não permite data source aws_availability_zones, então a lista é
# fixa. O número de AZs USADO é controlado por var.az_count (default 2) —
# evita criar subnets/NAT em excesso (3ª AZ sem uso = custo desperdiçado).
locals {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  az_count           = min(length(local.availability_zones), var.az_count)
}

# Subnets Públicas (para ALB e NAT Gateway)
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${count.index + 1}"
  }
}

# Subnets Privadas (para Backend, Frontend e RDS)
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "subnet-private-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-techstock"
  }
}

# NAT Gateway (precisamos de pelo menos 1 para as subnets privadas baixarem pacotes)
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "nat-techstock"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Tabelas de Rota
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "rt-private"
  }
}

# Associações
resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# NOTA: data source removido porque não temos permissão
# data "aws_availability_zones" "available" {}  # <-- COMENTADO