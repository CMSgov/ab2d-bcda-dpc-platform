locals {
  provider_domain = "token.actions.githubusercontent.com"
  repos = {
    ab2d = [
      "repo:CMSgov/ab2d-lambdas:*",
    ]
    bcda = [
      "repo:CMSgov/bcda-app:*",
    ]
    dpc = [
      "repo:CMSgov/dpc-app:*",
    ]
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_role" "admin" {
  name = var.legacy && var.app == "ab2d" ? "ct-ado-ab2d-application-admin" : "ct-ado-bcda-application-admin"
}

data "aws_iam_role" "dasg_admin" {
  name = "ct-ado-dasg-application-admin"
}

data "aws_iam_policy_document" "function_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  # Allow access from GitHub-hosted runners via OIDC for integration tests
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sts:TagSession",
    ]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_domain}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.provider_domain}:sub"
      values   = local.repos[var.app]
    }
  }

  # Allow access from admin role for manual checks
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn, data.aws_iam_role.dasg_admin.arn]
    }
  }
}

resource "aws_kms_key" "env_vars" {
  description         = "For ${var.name} function to decrypt and encrypt environment variables"
  enable_key_rotation = true
}

resource "aws_kms_alias" "env_vars" {
  name          = "alias/${var.name}-env-vars"
  target_key_id = aws_kms_key.env_vars.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "function_inline" {
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeNetworkInterfaces",
      "kms:Decrypt",
      "kms:Encrypt",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "function" {
  name = "${var.name}-function"
  path = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  assume_role_policy = data.aws_iam_policy_document.function_assume_role.json

  inline_policy {
    name   = "default-function"
    policy = data.aws_iam_policy_document.function_inline.json
  }

  dynamic "inline_policy" {
    for_each = var.function_role_inline_policies
    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }
}

# Get prod and sbx account IDs in the test environment for cross-account roles
data "aws_ssm_parameter" "prod_account" {
  count = var.legacy && var.env == "test" ? 1 : 0
  name  = "/${var.app}/prod/account-id"
}

data "aws_ssm_parameter" "sbx_account" {
  count = var.legacy && var.env == "test" ? 1 : 0
  name  = "/${var.app}/sbx/account-id"
}

data "aws_ssm_parameter" "prod_account_id" {
  count = !var.legacy && var.env == "test" ? 1 : 0
  name  = "/prod/account-id"
}

module "zip_bucket" {
  source = "../bucket"

  name = "${var.name}-function"
  cross_account_read_roles = var.env == "test" ? var.legacy ? [
    "arn:aws:iam::${data.aws_ssm_parameter.prod_account[0].value}:role/delegatedadmin/developer/${var.app}-prod-github-actions",
    "arn:aws:iam::${data.aws_ssm_parameter.sbx_account[0].value}:role/delegatedadmin/developer/${var.app}-sbx-github-actions",
  ] : [
    "arn:aws:iam::${data.aws_ssm_parameter.prod_account_id[0].value}:role/delegatedadmin/developer/${var.app}-prod-github-actions",
    "arn:aws:iam::${data.aws_ssm_parameter.prod_account_id[0].value}:role/delegatedadmin/developer/${var.app}-sandbox-github-actions",
  ] : []

  legacy        = var.legacy
  ssm_parameter = var.legacy ? null : "/${var.app}/${var.env}/${var.name}-bucket"
}

resource "aws_s3_object" "empty_function_zip" {
  count = var.create_function_zip ? 1 : 0

  bucket = module.zip_bucket.id
  key    = "function.zip"
  source = "${path.module}/dummy_function.zip"

  # This resource only exists to initialize the function, not manage it
  lifecycle {
    ignore_changes = all
  }
}

module "vpc" {
  source = "../vpc"

  app    = var.app
  env    = var.env
  legacy = var.legacy
}

module "subnets" {
  source = "../subnets"

  vpc_id = module.vpc.id
  app    = var.app
  layer  = "data"
  legacy = var.legacy
}

resource "aws_security_group" "function" {
  name        = "${var.name}-function"
  description = "For the ${var.name} function"
  vpc_id      = module.vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lambda_function" "this" {
  description   = var.description
  function_name = var.name
  s3_key        = "function.zip"
  s3_bucket     = module.zip_bucket.id
  kms_key_arn   = aws_kms_key.env_vars.arn
  role          = aws_iam_role.function.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = module.subnets.ids
    security_group_ids = [aws_security_group.function.id]
  }

  environment {
    variables = var.environment_variables
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  count = var.schedule_expression != "" ? 1 : 0

  name                = "${var.name}-function"
  description         = "Trigger ${var.name} function"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.schedule_expression != "" ? 1 : 0

  arn  = aws_lambda_function.this.arn
  rule = aws_cloudwatch_event_rule.this[0].name
}

resource "aws_lambda_permission" "cloudwatch_events" {
  count = var.schedule_expression != "" ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}
