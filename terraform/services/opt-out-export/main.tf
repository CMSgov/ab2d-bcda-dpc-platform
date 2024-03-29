locals {
  full_name = "${var.app}-${var.env}-opt-out-export"
  bfd_env   = var.env == "prod" ? "prod" : "test"
  cron = {
    # TODO Switch back to weekly for AB2D after testing period
    #ab2d = "cron(0 3 ? * TUE *)"
    ab2d = "cron(0 3 ? * * *)"
    bcda = "cron(0 3 ? * * *)"
    dpc  = "cron(0 3 ? * * *)"
  }
  ab2d_db_envs = {
    dev  = "dev"
    test = "east-impl"
    sbx  = "sbx-sandbox"
    prod = "east-prod"
  }
  db_sg_name = {
    ab2d = "ab2d-${local.ab2d_db_envs[var.env]}-database-sg"
    bcda = var.env == "sbx" ? "bcda-opensbx-rds" : "bcda-${var.env}-rds"
    dpc  = var.env == "sbx" ? "dpc-prod-sbx-db" : "dpc-${var.env}-db"
  }
  memory_size = {
    ab2d = 10240
    bcda = null
    dpc  = 1024
  }
}

data "aws_ssm_parameter" "bfd_account" {
  name = "/bfd/account-id"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/bfd-${local.bfd_env}-eft-${var.app}-bucket-role"]
  }
}

data "aws_ssm_parameter" "opt_out_db_host" {
  name = "/${var.app}/${var.env}/opt-out/db-host"
}

module "opt_out_export_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Exports data files to a BFD bucket for opt-out"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.attributionDataShare.AttributionDataShareHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  schedule_expression = var.env == "prod" ? local.cron[var.app] : "cron(0 15 ? * * *)"

  environment_variables = {
    ENV              = var.env
    APP_NAME         = "${var.app}-${var.env}-opt-out-export"
    S3_UPLOAD_BUCKET = "bfd-${var.env == "prod" ? "prod" : "test"}-eft"
    S3_UPLOAD_PATH   = "bfdeft01/${var.app}/out"
    DB_HOST          = data.aws_ssm_parameter.opt_out_db_host.value
  }
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
  description = "opt-out-export function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.opt_out_export_function.security_group_id
}
