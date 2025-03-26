
variable "region" {
  type    = string
  default = "eu-west-1"
  description = "Region to deploy the LAMP Stack Lab"
}

variable "image" {
  type = string
  description = "Image for the Apache Server"
}


# Data
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "db-creds-v2"
}

# Locals
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.db_creds.secret_string
  )
}
