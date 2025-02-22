locals {
  secret_date = "2020-01-02-09-15-01"
  gdit_security_group_names = [
    "bcda-${var.env}-vpn-private",
    "bcda-${var.env}-vpn-public",
    "bcda-${var.env}-remote-management",
    "bcda-${var.env}-enterprise-tools",
    "Allow internet zscaler traffic private"
  ]
}

data "aws_default_tags" "data_tags" {}

# Fetching the secret for database username
data "aws_secretsmanager_secret" "secret_database_user" {
  name = var.app == "ab2d" ? "ab2d/${local.db_name}/module/db/database_user/${local.secret_date}" : var.app == "bcda" ? "${var.app}/${var.env}/db/username" : null
}

data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.secret_database_user.id
}

# Fetching the secret for database password
data "aws_secretsmanager_secret" "secret_database_password" {
  name = var.app == "ab2d" ? "ab2d/${local.db_name}/module/db/database_password/${local.secret_date}" : var.app == "bcda" ? "${var.app}/${var.env}/db/password" : null
}

data "aws_secretsmanager_secret_version" "database_password" {
  secret_id = data.aws_secretsmanager_secret.secret_database_password.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "target_vpc" {
  filter {
    name = "tag:Name"
    values = [
      var.app == "ab2d" ? local.db_name : "${var.app}-${var.env}-vpc"
    ]
  }
}

data "aws_subnets" "db" {
  filter {
    name = "tag:Name"
    values = var.app == "ab2d" ? [
      "${local.db_name}-private-a",
      "${local.db_name}-private-b"
      ] : [
      "${var.app}-${var.env}-az1-data",
      "${var.app}-${var.env}-az2-data"
    ]
  }
}

# Fetch the security group for ab2d
data "aws_security_group" "controller_security_group_id" {
  count = var.app == "ab2d" ? 1 : 0

  tags = {
    Name = "${local.db_name}-deployment-controller-sg"
  }
}

data "aws_kms_alias" "main_kms" {
  count = var.app == "ab2d" ? 1 : 0 # Only query the KMS alias for ab2d
  name  = "alias/${local.db_name}-main-kms"
}

data "aws_security_group" "app_sg" {
  count = var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["bcda-api-${var.env}"] # This will look for the bcda api app security group named based on the environment
  }
}

data "aws_security_group" "worker_sg" {
  count = var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["bcda-worker-${var.env}"] # This looks for the bcda worker security group named based on the environment
  }
}

data "aws_security_group" "gdit" {
  for_each = var.app == "bcda" ? toset(local.gdit_security_group_names) : toset([])

  filter {
    name   = "description" # Filtering by security group description
    values = [each.value]
  }
  filter {
    name   = "vpc-id"                     # Filter by VPC ID
    values = [data.aws_vpc.target_vpc.id] # Dynamically get VPC ID
  }
}
