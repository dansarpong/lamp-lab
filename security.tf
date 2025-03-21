# Security Groups

# Linux
resource "aws_security_group" "lab-linux-sg" {
  name        = "lab-linux-sg"
  description = "Linux SG"
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-linux-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "limit_ssh" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id = aws_security_group.lab-linux-sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  prefix_list_id = data.aws_ec2_managed_prefix_list.instance_connect.id
}

resource "aws_vpc_security_group_ingress_rule" "linux_allow_alb" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.lab-linux-sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.lab-alb-sg.id
}

resource "aws_vpc_security_group_egress_rule" "linux_allow_out" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id = aws_security_group.lab-linux-sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# MySQL
resource "aws_security_group" "lab-mysql-sg" {
  name        = "lab-mysql-sg"
  description = "MySQL SG"
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-mysql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_allow_linux" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.lab-mysql-sg.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.lab-linux-sg.id
}

resource "aws_vpc_security_group_egress_rule" "mysql_allow_out" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id = aws_security_group.lab-mysql-sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ALB
resource "aws_security_group" "lab-alb-sg" {
  name        = "lab-alb-sg"
  description = "Application LB SG"
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "lab-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_allow_http" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id = aws_security_group.lab-alb-sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_allow_linux" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.lab-alb-sg.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.lab-linux-sg.id
}


# IAM role
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Instance Profile
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cloudwatch_instance_profile" {
  name = "ec2-cloudwatch-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}


