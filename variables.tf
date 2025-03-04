
variable "region" {
  type    = string
  default = "eu-west-1"
  description = "Region to deploy the LAMP Stack Lab"
}


# Data
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.${var.region}.ec2-instance-connect"
}

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "db-creds-v1"
}

# Locals
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.db_creds.secret_string
  )
}
