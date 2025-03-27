# Cloudwatch

# RDS Logs
resource "aws_cloudwatch_log_group" "rds_mysql_error" {
  name              = "/aws/rds/instance/${aws_db_instance.lab-mysql.identifier}/error"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_mysql_general" {
  name              = "/aws/rds/instance/${aws_db_instance.lab-mysql.identifier}/general"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_mysql_slowquery" {
  name              = "/aws/rds/instance/${aws_db_instance.lab-mysql.identifier}/slowquery"
  retention_in_days = 7
}

# ECS logs
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "ecs_logs"
  retention_in_days = 7
}

# ALB Requests High Alarm
resource "aws_cloudwatch_metric_alarm" "alb-request-count-high" {
  alarm_name          = "alb-request-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 200
  alarm_description   = "Scale up when requests per target exceed 200"
  alarm_actions       = [aws_appautoscaling_policy.ecs-scale-up.arn, aws_sns_topic.cloudwatch-alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.lab-alb.arn_suffix
    TargetGroup  = aws_lb_target_group.lab-alb-tg.arn_suffix
  }
}

# ALB Requests Low Alarm
resource "aws_cloudwatch_metric_alarm" "alb-request-count-low" {
  alarm_name          = "alb-request-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Scale down when requests per target is below 50"
  alarm_actions       = [aws_appautoscaling_policy.ecs-scale-down.arn]

  dimensions = {
    LoadBalancer = aws_lb.lab-alb.arn_suffix
    TargetGroup  = aws_lb_target_group.lab-alb-tg.arn_suffix
  }
}

# ALB 4XX Error Count Alarm
resource "aws_cloudwatch_metric_alarm" "alb-4xx-alarm" {
  alarm_name          = "alb-4xx-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 20
  alarm_description   = "Monitor ALB 4XX errors and send email"
  alarm_actions       = [aws_sns_topic.cloudwatch-alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.lab-alb.arn_suffix
  }
}


# SNS

# Topic for CW Alarms
resource "aws_sns_topic" "cloudwatch-alarms" {
  name = "lab-cloudwatch-alarms"
}

# Topic Subscription for Email Notifications
resource "aws_sns_topic_subscription" "email-subscription" {
  topic_arn = aws_sns_topic.cloudwatch-alarms.arn
  protocol  = "email"
  endpoint  = var.email
}
