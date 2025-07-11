locals {
  secret_date = "2020-01-02-09-15-01"
  #NOTE: `db_username` and `db_password` are path/names to secrets for secrets manager datasource
  db_username = {
    ab2d = "${var.app}/${local.db_name}/module/db/database_user/${local.secret_date}"
    bcda = "${var.app}/${var.env}/db/username"
    dpc  = "${var.app}/${var.env}/db/username"
  }[var.app]

  db_password = {
    ab2d = "${var.app}/${local.db_name}/module/db/database_password/${local.secret_date}"
    bcda = "${var.app}/${var.env}/db/password"
    dpc  = "${var.app}/${var.env}/db/password"
  }[var.app]
}

# Fetching the secret for database username
data "aws_secretsmanager_secret" "database_user" {
  name = "${var.app}/${var.env}/db/username"
}

data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.database_user.id
}

# Fetching the secret for database password
data "aws_secretsmanager_secret" "database_password" {
  name = "${var.app}/${var.env}/db/password"
}

data "aws_secretsmanager_secret_version" "database_password" {
  secret_id = data.aws_secretsmanager_secret.database_password.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_subnets" "db" {
  filter {
    name = "tag:Name"
    values = [
      "${var.app}-east-${var.env}-private-a",
      "${var.app}-east-${var.env}-private-b",
      "${var.app}-east-${var.env}-private-c"
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

data "aws_kms_alias" "default_rds" {
  name = "alias/aws/rds"
}

data "aws_security_group" "app_sg" {
  #FIXME: Temporarily disabled in greenfield
  count = var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.app}-api-${var.env}"] # This will look for the bcda api app security group named based on the environment
  }
}

data "aws_security_group" "worker_sg" {
  #FIXME: Temporarily disabled in greenfield
  count = var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.app}-worker-${var.env}"] #This looks for the bcda worker security group named based on the environment
  }
}

data "aws_ssm_parameter" "cdap_mgmt_vpc_cidr" {
  name = "/cdap/mgmt-vpc/cidr"
}

data "aws_ssm_parameter" "quicksight_cidr_blocks" {
  count = var.app != "ab2d" ? 1 : 0
  name  = "/${var.app}/${var.env}/quicksight-rds/cidr-blocks"
}
