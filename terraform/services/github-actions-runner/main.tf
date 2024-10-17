data "aws_vpc" "managed" {
  filter {
    name   = "tag:Name"
    values = ["bcda-managed-vpc"]
  }
}

data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.managed.id]
  }
  tags = {
    Layer = "app"
  }
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_iam_policy_document" "runner" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    resources = ["arn:aws:iam::*:role/delegatedadmin/developer/*-github-actions"]
  }
  statement {
    actions   = ["ssm:GetParameters"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "runner" {
  name = "github-actions-runner"
  path = "/delegatedadmin/developer/"

  description = "The runner has permission to assume the GitHub Actions deploy role in any account and get parameters"

  policy = data.aws_iam_policy_document.runner.json
}

data "aws_security_group" "vpn" {
  filter {
    name   = "description"
    values = ["bcda-managed-vpn-private"]
  }
}

module "github-actions-runner" {
  source  = "philips-labs/github-runner/aws"
  version = "5.17.0"

  aws_region = "us-east-1"
  vpc_id     = data.aws_vpc.managed.id
  subnet_ids = data.aws_subnets.app.ids

  github_app = {
    key_base64     = var.key_base64
    id             = var.app_id
    webhook_secret = var.webhook_secret
  }

  # match the volume size of the source AMI snapshot
  block_device_mappings = [{
    device_name           = "/dev/xvda"
    delete_on_termination = true
    volume_size           = 31
    encrypted             = true
  }]

  webhook_lambda_zip                = "lambdas-download/webhook.zip"
  runner_binaries_syncer_lambda_zip = "lambdas-download/runner-binaries-syncer.zip"
  runners_lambda_zip                = "lambdas-download/runners.zip"
  ami_housekeeper_lambda_zip        = "lambdas-download/ami-housekeeper.zip"

  ami_owners = [var.ami_account]
  ami_filter = {
    name  = ["github-actions-runner-*"],
    state = ["available"]
  }

  role_path                 = "/delegatedadmin/developer/"
  role_permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn

  enable_ssm_on_runners = true
  enable_userdata       = false

  idle_config = [{
    cron             = "* * 9-17 * * 1-5"
    timeZone         = "America/New_York"
    idleCount        = 2
    evictionStrategy = "oldest_first"
  }]

  # Set boot time to avoid terminating instances before user data is executed
  # Defaults to 5 minutes
  runner_boot_time_in_minutes = 10

  runner_iam_role_managed_policy_arns  = [aws_iam_policy.runner.arn]
  runner_additional_security_group_ids = [data.aws_security_group.vpn.id]

  instance_target_capacity_type = "on-demand"
  instance_types = [
    "t3.large",
  ]

  enable_ami_housekeeper = true
  ami_housekeeper_cleanup_config = {
    launchTemplateNames = ["github-actions-action-runner"]
    minimumDaysOld      = 90
    amiFilters = [
      {
        Name   = "name"
        Values = ["github-actions-runner-*"]
      }
    ]
  }
}
