locals {
  full_name = "${var.app}-${var.env}-cclf-import"
  bfd_env   = var.env == "prod" ? "prod" : "test"
  db_sg_name = var.legacy ? {
    bcda = "bcda-${var.env}-rds"
  }[var.app] : "${var.app}-${var.env}-db"
  memory_size = {
    bcda = 2048
  }
}

data "aws_ssm_parameter" "bfd_account" {
  name = "/bfd/account-id"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions = ["sts:AssumeRole"]
    resources = var.legacy ? [
      "arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/bfd-${local.bfd_env}-eft-${var.app}-bucket-role"
      ] : [
      "arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/delegatedadmin/developer/bfd-${local.bfd_env}-eft-${var.app}-ct-bucket-role"
    ]
  }
}

module "cclf_import_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Ingests the most recent CCLF from BFD"

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-cclf-import"
  }
}

# Set up queue for receiving messages when a file is added to the bucket

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/cclf-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "cclf_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.cclf_import_function.name
  sns_topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
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
  description = "cclf-import function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.cclf_import_function.security_group_id
}
