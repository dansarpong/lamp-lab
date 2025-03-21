# VPC
resource "aws_vpc" "lab-vpc" {
  cidr_block = "123.0.0.0/16"

  tags = {
    Name = "lab-vpc"
  }
}

resource "aws_internet_gateway" "lab-igw" {
  vpc_id = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-igw"
  }
}


# Subnets

# Public
resource "aws_subnet" "lab-public-a" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "123.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "lab-public-a"
  }
}

resource "aws_subnet" "lab-public-b" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "123.0.3.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "lab-public-b"
  }
}

resource "aws_route_table" "lab-public" {
  vpc_id = aws_vpc.lab-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab-igw.id
  }

  tags = {
    Name = "lab-public"
  }
}

resource "aws_route_table_association" "lab_public_a_assoc" {
  subnet_id      = aws_subnet.lab-public-a.id
  route_table_id = aws_route_table.lab-public.id
}

resource "aws_route_table_association" "lab_public_b_assoc" {
  subnet_id      = aws_subnet.lab-public-b.id
  route_table_id = aws_route_table.lab-public.id
}

# Private
resource "aws_subnet" "lab-private-a" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "123.0.2.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "lab-private-a"
  }
}

resource "aws_subnet" "lab-private-b" {
  vpc_id            = aws_vpc.lab-vpc.id
  cidr_block        = "123.0.4.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "lab-private-b"
  }
}

resource "aws_route_table" "lab-private" {
  vpc_id = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-private"
  }
}

resource "aws_route_table_association" "lab_private_a_assoc" {
  subnet_id      = aws_subnet.lab-private-a.id
  route_table_id = aws_route_table.lab-private.id
}

resource "aws_route_table_association" "lab_private_b_assoc" {
  subnet_id      = aws_subnet.lab-private-b.id
  route_table_id = aws_route_table.lab-private.id
}


# DB Subnet Group
resource "aws_db_subnet_group" "lab-mysql-subnet-group" {
  name       = "lab-mysql-subnet-group"
  subnet_ids = [aws_subnet.lab-private-a.id, aws_subnet.lab-private-b.id]

  tags = {
    Name = "MySQL Subnet Group"
  }
}
