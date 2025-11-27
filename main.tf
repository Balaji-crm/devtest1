locals {
  prefix = var.name_prefix
}

# -----------------------
# VPC
# -----------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# -----------------------
# Internet Gateway
# -----------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# -----------------------
# Public subnets
# -----------------------
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public-${each.key}"
    Tier = "public"
  }
}

# -----------------------
# Private subnets (no NAT -> no internet for these)
# -----------------------
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = {
    Name = "${local.prefix}-private-${each.key}"
    Tier = "private"
  }
}

# -----------------------
# Public Route Table (routes 0.0.0.0/0 to IGW)
# -----------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.prefix}-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# -----------------------
# (Intentionally) No NAT Gateway or public route for private subnets
# Private subnets will not have a default route to the internet.
# -----------------------

# -----------------------
# Security Group - web/bastion
# -----------------------
resource "aws_security_group" "public_sg" {
  name        = "${local.prefix}-public-sg"
  description = "Allow SSH/HTTP/HTTPS to public instances; allow internal VPC traffic"
  vpc_id      = aws_vpc.this.id

  # SSH (restrict in production)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all from VPC for internal communications
  ingress {
    description = "VPC internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress - allow all outbound (public instances can reach internet)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-public-sg"
  }
}

# Security Group for private resources (no internet access required)
resource "aws_security_group" "private_sg" {
  name        = "${local.prefix}-private-sg"
  description = "Allow internal VPC traffic, allow from public SG where needed"
  vpc_id      = aws_vpc.this.id

  # allow from VPC CIDR
  ingress {
    description = "VPC internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # optionally allow SSH from the public security group (bastion)
  ingress {
    description                = "Allow SSH from public SG (bastion)"
    from_port                  = 22
    to_port                    = 22
    protocol                   = "tcp"
    security_groups            = [aws_security_group.public_sg.id]
    self                       = false
  }

  egress {
    description = "Allow all outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.prefix}-private-sg"
  }
}


