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
resource "aws_cloudwatch_log_group" "ec2_apache_error" {
  name              = "EC2-ApacheError"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "ec2_apache_access" {
  name              = "EC2-ApacheAccess"
  retention_in_days = 7
}
