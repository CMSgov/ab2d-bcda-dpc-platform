locals {
  full_name  = "dpc-${var.env}-api-waf-sync"
  db_sg_name = "dpc-${var.env}-db"
}

module "api_waf_sync_function" {
  source = "../../modules/function"

  app = "dpc"
  env = var.env

  name        = local.full_name
  description = "Synchronizes the IP whitelist in DPC with the WAF IP Set"

  handler = "bootstrap"
  runtime = "provided.al2"

  function_role_inline_policies = {
    waf-access = data.aws_iam_policy_document.aws_waf_access.json
  }

  schedule_expression = "cron(0/10 * * * ? *)"

  environment_variables = {
    ENV             = var.env
    APP_NAME        = "dpc-${var.env}-api-waf-sync"
    WAF_IP_SET_NAME = "DPC_${upper(var.env)}_Implementer_IP_Set"
  }
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
  description = "api-waf-sync function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.api_waf_sync_function.security_group_id
}

# Because we inline policies, we cannot just link to aws:policy/AWSWAFFullAccess
data "aws_iam_policy_document" "aws_waf_access" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "wafv2:GetIpSet",
      "wafv2:UpdateIpSet",
    ]
  }
}
