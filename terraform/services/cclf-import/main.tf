locals {
  full_name = "${var.app}-${var.env}-cclf-import"
  bcda_db_envs = {
    dev  = "dev"
    test = "east-impl"
    prod = "east-prod"
  }
  db_sg_name = {
    ab2d = "ab2d-${local.bcda_db_envs[var.env]}-database-sg"
    bcda = "bcda-${var.env}-rds"
    dpc  = "dpc-${var.env}-db"
  }
  memory_size = {
    ab2d = 1024
    bcda = 1024
    dpc  = null
  }
}

data "aws_ssm_parameter" "bfd_bucket_role_arn" {
  name = "/cclf-import/${var.app}/${var.env}/bfd-bucket-role-arn"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [data.aws_ssm_parameter.bfd_bucket_role_arn.value]
  }
}

data "aws_ssm_parameter" "cclf_db_host" {
  name = "/${var.app}/${var.env}/cclf/db-host"
}

module "cclf_import_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Ingests the most recent CCLF from BFD"

  handler = var.app == "bcda" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap" # TODO: check handlers
  runtime = var.app == "bcda" ? "java11" : "provided.al2" # TODO: check runtime

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-cclf-import"
    DB_HOST  = data.aws_ssm_parameter.opt_out_db_host.value #TODO: What is this
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
  name = local.db_sg_name[var.app]
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
