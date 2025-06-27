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
  db_sg_name = "${var.app}-${var.env}-db"
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
    actions = ["sts:AssumeRole"]
    resources = [
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

locals {
  #FIXME: database host parameters should be standardized
  db_hosts = sensitive({
    ab2d = "postgres://${data.aws_db_instance.this.address}:5432"
    bcda = "postgres://${data.aws_db_instance.this.address}:5432/bcda"
    dpc  = data.aws_db_instance.this.address
  })
  opt_out_db_host = local.db_hosts[var.app]
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
    DB_HOST          = local.opt_out_db_host
  }
}

# Add a rule to the database security group to allow access from the function

data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_vpc_security_group_ingress_rule" "function_access" {
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
  description = "opt-out-export function access"

  security_group_id            = data.aws_security_group.db.id
  referenced_security_group_id = module.opt_out_export_function.security_group_id
}
