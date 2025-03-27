# Variables
variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "Region to deploy the LAMP Stack Lab"
}

variable "image" {
  type        = string
  description = "Image for the Apache Server"
}

variable "email" {
  type        = string
  description = "Email used for CW Alarms from SNS"
}

variable "db-creds" {
  type        = string
  description = "Secret name of the db creds saved on AWS Secrets Manager"
}


# Data
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = var.db-creds
}

# Locals
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.db_creds.secret_string
  )
}
