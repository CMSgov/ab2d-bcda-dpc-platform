locals {
  full_name         = "${var.app}-${var.env}-admin-create-aco-creds"
  db_sg_name        = var.legacy ? "bcda-${var.env == "sbx" ? "opensbx" : var.env}-rds" : "bcda-${var.env}-db"
  memory_size       = 256
  creds_bucket_name = var.legacy ? ("bcda-aco-credentials/${var.env == "sbx" ? "opensbx" : var.env}/*") : ("bcda-${var.env}-aco-creds-*")
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_kms_alias" "aco_creds_kms" {
  name = "alias/bcda-aco-creds-kms"
}

data "aws_iam_policy_document" "creds_bucket" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.creds_bucket_name}"]
  }
}

data "aws_iam_policy_document" "kms_access" {
  statement {
    actions = ["kms:ListAliases"]
    // must be *, see: https://docs.aws.amazon.com/kms/latest/developerguide/alias-access.html#alias-access-view
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kms_generate" {
  statement {
    actions   = ["kms:GenerateDataKey"]
    resources = [data.aws_kms_alias.aco_creds_kms.target_key_arn]
  }
}

module "admin_create_aco_creds_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Finds and Creates ACO Credentials for passed in ACO ID and IP addresses"

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size

  function_role_inline_policies = {
    assume-bucket-role       = data.aws_iam_policy_document.creds_bucket.json
    assume-kms-role          = data.aws_iam_policy_document.kms_access.json
    assume-kms-generate-role = data.aws_iam_policy_document.kms_generate.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-admin-create-aco-creds"
  }

  legacy = var.legacy
}

# Add a rule to the database security group to allow access from the function
data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_security_group_rule" "function_access" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  description = "admin-create-aco-creds function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.admin_create_aco_creds_function.security_group_id
}
