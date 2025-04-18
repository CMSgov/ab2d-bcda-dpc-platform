locals {
  full_name = "${var.app}-${var.env}-opt-out-export"
  bfd_env   = var.env == "prod" ? "prod" : "test"
  cron = {
    ab2d = {
      prod = "cron(0 1 ? * WED *)"
      test = "cron(0 13 ? * * *)"
      dev  = "cron(0 15 ? * * *)"
    }
    bcda = {
      prod = "cron(0 1 ? * * *)"
      test = "cron(0 13 ? * * *)"
      dev  = "cron(0 15 ? * * *)"
    }
    dpc = {
      prod = "cron(0 1 ? * * *)"
      test = "cron(0 13 ? * * *)"
      dev  = "cron(0 15 ? * * *)"
    }
  }
  ab2d_db_envs = {
    dev  = "dev"
    test = "east-impl"
    prod = "east-prod"
  }
  db_sg_name = {
    ab2d = "ab2d-${local.ab2d_db_envs[var.env]}-database-sg"
    bcda = "bcda-${var.env}-rds"
    dpc  = "dpc-${var.env}-db"
  }
  memory_size = {
    ab2d = 10240
    bcda = null
    dpc  = 2048
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

  handler = var.app == "ab2d" ? "gov.cms.ab2d.attributiondatashare.AttributionDataShareHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java17" : "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  schedule_expression = local.cron[var.app][var.env]

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

resource "aws_vpc_security_group_ingress_rule" "function_access" {
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
  description = "opt-out-export function access"

  security_group_id            = data.aws_security_group.db.id
  referenced_security_group_id = module.opt_out_export_function.security_group_id
}
