terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.87.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Lab = "LAMP"
    }
  }
}

# RDS
resource "aws_db_instance" "lab-mysql" {
  identifier              = "lab-mysql"
  engine                  = "mysql"
  engine_version          = "8.4.3"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp3"
  username                = local.db_creds.username
  password                = local.db_creds.password
  multi_az                = true
  db_subnet_group_name    = aws_db_subnet_group.lab-mysql-subnet-group.name
  vpc_security_group_ids  = [aws_security_group.lab-mysql-sg.id]
  skip_final_snapshot     = true
  storage_encrypted       = true
  backup_retention_period = 5

  publicly_accessible = false
  apply_immediately   = false
  maintenance_window  = "sun:03:00-sun:04:00"
  backup_window       = "01:00-02:00"

  enabled_cloudwatch_logs_exports = [ "error", "general", "slowquery" ]
}

resource "aws_db_subnet_group" "lab-mysql-subnet-group" {
  name       = "lab-mysql-subnet-group"
  subnet_ids = [aws_subnet.lab-private-a.id, aws_subnet.lab-private-b.id]

  tags = {
    Name = "MySQL Subnet Group"
  }
}


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


# Launch Template and Autoscaling Group
resource "aws_launch_template" "linux-server" {
  name          = "linux-server"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  user_data = base64encode(templatefile("user-data.sh", {
    db_user     = aws_db_instance.lab-mysql.username
    db_password = aws_db_instance.lab-mysql.password
    db_host     = aws_db_instance.lab-mysql.endpoint
    db_port     = aws_db_instance.lab-mysql.port
  }))
  update_default_version = true

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.lab-linux-sg.id]
  }

  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ec2_cloudwatch_instance_profile.name
  # }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-server"
    }
  }
}

resource "aws_autoscaling_group" "lab-autoscaling" {
  name             = "lab-autoscaling"
  desired_capacity = 1
  min_size         = 1
  max_size         = 4
  vpc_zone_identifier = [
    aws_subnet.lab-public-a.id,
    aws_subnet.lab-public-b.id,
  ]
  target_group_arns = [aws_lb_target_group.lab-alb-tg.arn]

  launch_template {
    id      = aws_launch_template.linux-server.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "scale-up" {
  name                   = "scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.lab-autoscaling.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale-down" {
  name                   = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.lab-autoscaling.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}


# CloudWatch
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when CPU utilization exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.scale-up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.lab-autoscaling.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Alarm when CPU utilization falls below 30%"
  alarm_actions       = [aws_autoscaling_policy.scale-down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.lab-autoscaling.name
  }
}

# Load Balancer
resource "aws_lb" "lab-alb" {
  name               = "lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lab-alb-sg.id]
  subnets            = [aws_subnet.lab-public-a.id, aws_subnet.lab-public-b.id]
}

resource "aws_lb_listener" "lab-alb-listener" {
  load_balancer_arn = aws_lb.lab-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab-alb-tg.arn
  }
}

resource "aws_lb_target_group" "lab-alb-tg" {
  name     = "lab-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab-vpc.id

  health_check {
    port     = 80
    protocol = "HTTP"
    timeout  = 5
    interval = 10
  }
}


# Cloudwatch
# RDS
resource "aws_cloudwatch_log_group" "rds_mysql_error" {
  name              = "/aws/rds/instance/lab-mysql/error"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_mysql_general" {
  name              = "/aws/rds/instance/lab-mysql/general"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_mysql_slowquery" {
  name              = "/aws/rds/instance/lab-mysql/slowquery"
  retention_in_days = 7
}
# EC2
# resource "aws_cloudwatch_log_group" "ec2_apache_error" {
#   name              = "EC2-ApacheError"
#   retention_in_days = 7
# }

# resource "aws_cloudwatch_log_group" "ec2_apache_access" {
#   name              = "EC2-ApacheAccess"
#   retention_in_days = 7
# }


# IAM role and Instance Profile
# resource "aws_iam_role" "ec2_cloudwatch_role" {
#   name = "ec2-cloudwatch-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_policy" {
#   role       = aws_iam_role.ec2_cloudwatch_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
# }

# resource "aws_iam_instance_profile" "ec2_cloudwatch_instance_profile" {
#   name = "ec2-cloudwatch-instance-profile"
#   role = aws_iam_role.ec2_cloudwatch_role.name
# }

