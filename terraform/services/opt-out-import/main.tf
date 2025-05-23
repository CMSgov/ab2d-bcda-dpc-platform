locals {
  full_name = "${var.app}-${var.env}-opt-out-import"
  bfd_env   = var.env == "prod" ? "prod" : "test"
  ab2d_db_envs = {
    dev  = "dev"
    test = "east-impl"
    prod = "east-prod"
  }
  db_sg_name = var.legacy ? {
    ab2d = "ab2d-${local.ab2d_db_envs[var.env]}-database-sg"
    bcda = "bcda-${var.env}-rds"
    dpc  = "dpc-${var.env}-db"
  }[var.app] : "${var.app}-${var.env}-db"
  memory_size = {
    ab2d = 1024
    bcda = null
    dpc  = null
  }
  handler_name = {
    ab2d = "gov.cms.ab2d.optout.OptOutHandler"
    bcda = "bootstrap"
    dpc  = "bootstrap"
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

data "aws_db_instances" "this" {
  tags = {
    environment = var.env
    application = var.app
  }
}

data "aws_db_instance" "this" {
  db_instance_identifier = one(one(data.aws_db_instances.this[*]).instance_identifiers)
}

#TODO: Post greenfield migration removal
data "aws_ssm_parameter" "opt_out_db_host" {
  count = var.legacy ? 1 : 0
  name  = "/${var.app}/${var.env}/opt-out/db-host"
}

locals {
  #FIXME: database host parameters should be standardized
  db_hosts = sensitive({
    ab2d = "postgres://${data.aws_db_instance.this.address}:5432"
    bcda = "postgres://${data.aws_db_instance.this.address}:5432/bcda"
    dpc  = data.aws_db_instance.this.address
  })
  #TODO: Post greenfield migration removal: just use the db_hosts value
  opt_out_db_host = var.legacy ? data.aws_ssm_parameter.opt_out_db_host[0].value : local.db_hosts[var.app]
}

module "opt_out_import_function" {
  source = "../../modules/function"

  app    = var.app
  env    = var.env
  legacy = var.legacy

  name        = local.full_name
  description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = local.handler_name[var.app]
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-import"
    DB_HOST  = local.opt_out_db_host
  }
}

# Set up queue for receiving messages when a file is added to the bucket

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "opt_out_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.opt_out_import_function.name
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
  description = "opt-out-import function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.opt_out_import_function.security_group_id
}
