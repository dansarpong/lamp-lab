
# Launch Template
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

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_cloudwatch_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-server"
    }
  }
}

# Autoscaling Group
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

# Autoscaling Policies with Cloudwatch Alarms
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

resource "aws_cloudwatch_metric_alarm" "alb_request_count_high" {
  alarm_name          = "alb-request-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Sum"
  threshold           = 200
  alarm_description   = "Scale up when requests per target exceed 200"
  alarm_actions       = [aws_autoscaling_policy.scale-up.arn]

  dimensions = {
    LoadBalancer = aws_lb.lab-alb.arn_suffix
    TargetGroup  = aws_lb_target_group.lab-alb-tg.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_request_count_low" {
  alarm_name          = "alb-request-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Scale down when requests per target is below 50"
  alarm_actions       = [aws_autoscaling_policy.scale-down.arn]

  dimensions = {
    LoadBalancer = aws_lb.lab-alb.arn_suffix
    TargetGroup  = aws_lb_target_group.lab-alb-tg.arn_suffix
  }
}

# Application Load Balancer
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
    interval = 100
  }
}
