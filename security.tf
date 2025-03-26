# Security Groups

# ECS
resource "aws_security_group" "ecs-sg" {
  name        = "ecs-sg"
  description = "ECS SG"
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_allow_alb" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.ecs-sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.lab-alb-sg.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_allow_out" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id = aws_security_group.ecs-sg.id
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

resource "aws_vpc_security_group_ingress_rule" "mysql_allow_ecs" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.lab-mysql-sg.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.ecs-sg.id
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

resource "aws_vpc_security_group_egress_rule" "alb_allow_ecs" {
  lifecycle {
    create_before_destroy = true
  }

  security_group_id            = aws_security_group.lab-alb-sg.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.ecs-sg.id
}


# ECS IAM Roles
resource "aws_iam_role" "ecs-task-execution-role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy" {
  role       = aws_iam_role.ecs-task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_manager_policy" {
  role       = aws_iam_role.ecs-task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role" "ecs-task-role" {
  name = "ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.ecs-task-role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
