locals {
  secret_date = "2020-01-02-09-15-01"
}

data "aws_default_tags" "data_tags" {}

data "aws_secretsmanager_secret" "secret_database_password" {
  name = "ab2d/${local.db_name}/module/db/database_password/${local.secret_date}"
}
data "aws_secretsmanager_secret_version" "database_password" {
  secret_id = data.aws_secretsmanager_secret.secret_database_password.id
}

data "aws_secretsmanager_secret" "secret_database_user" {
  name = "ab2d/${local.db_name}/module/db/database_user/${local.secret_date}"
}
data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.secret_database_user.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

/*data "aws_vpc" "target_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${local.db_name}"]
  }
}*/
data "aws_vpc" "target_vpc" {
  filter {
    name = "tag:Name"
    values = [
      var.app == "ab2d" ? local.db_name : "${var.app}-${var.env}-vpc"
    ]
  }
}


data "aws_subnet" "private_subnet_a" {
  filter {
    name   = "tag:Name"
    values = ["${local.db_name}-private-a"]
  }
}

data "aws_subnet" "private_subnet_b" {
  filter {
    name   = "tag:Name"
    values = ["${local.db_name}-private-b"]
  }
}

/*ata "aws_subnet_ids" "bcda_subnets" {
  count = var.app == "bcda" ? 1 : 0

  vpc_id = data.aws_vpc.target_vpc.id

  tags = {
    Layer = "data"
  }
}*/

data "aws_security_group" "controller_security_group_id" {
  tags = {
    Name = "${local.db_name}-deployment-controller-sg"
  }
}

data "aws_kms_alias" "main_kms" {
  name = "alias/${local.db_name}-main-kms"
}
