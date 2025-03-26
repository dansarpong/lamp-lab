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

# ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "ECS-Logs"
  retention_in_days = 7
}