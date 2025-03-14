locals {
  stdenv      = var.env == "sbx" ? "opensbx" : var.env
  secret_date = "2020-01-02-09-15-01"
  gdit_security_group_names = [
    "bcda-${local.stdenv}-vpn-private",
    "bcda-${local.stdenv}-vpn-public",
    "bcda-${local.stdenv}-remote-management",
    "bcda-${local.stdenv}-enterprise-tools",
    "bcda-${local.stdenv}-allow-zscaler-private"
  ]
}

data "aws_default_tags" "data_tags" {}

# Fetching the secret for database username
data "aws_secretsmanager_secret" "secret_database_user" {
  name = var.app == "ab2d" ? "ab2d/${local.db_name}/module/db/database_user/${local.secret_date}" : var.app == "bcda" ? "${var.app}/${local.stdenv}/rds-main-credentials" : null
}

data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.secret_database_user.id
}

# Fetching the secret for database password
data "aws_secretsmanager_secret" "secret_database_password" {
  count = var.app == "ab2d" ? 1 : 0
  name  = "ab2d/${local.db_name}/module/db/database_password/${local.secret_date}"
}

data "aws_secretsmanager_secret_version" "database_password" {
  count     = var.app == "ab2d" ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.secret_database_password[0].id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "target_vpc" {
  filter {
    name = "tag:Name"
    values = [
      var.app == "ab2d" ? local.db_name : "${var.app}-${local.stdenv}-vpc"
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
      "${var.app}-${local.stdenv}-az1-data",
      "${var.app}-${local.stdenv}-az2-data",
      "${var.app}-${local.stdenv}-az3-data"
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
    values = ["${var.app}-api-${local.stdenv}"] # This will look for the bcda api app security group named based on the environment
  }
}

data "aws_security_group" "worker_sg" {
  count = var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.app}-worker-${local.stdenv}"] #This looks for the bcda worker security group named based on the environment
  }
}

data "aws_security_group" "gdit" {
  for_each = var.app == "bcda" ? toset(local.gdit_security_group_names) : toset([])

  filter {
    name   = "tag:Name" # Filter by 'Name' tag
    values = [each.value]
  }
}

data "aws_security_group" "github_runner" {
  count = var.app != "ab2d" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["github-actions-action-runner"]
  }
}

data "aws_ssm_parameter" "quicksight_cidr_blocks" {
  count = var.app != "ab2d" ? 1 : 0
  name  = "/${var.app}/${var.env}/quicksight-rds/cidr-blocks"
}
