locals {
  provider_domain = "token.actions.githubusercontent.com"
  repos = {
    ab2d = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/ab2d-contracts:*",
      "repo:CMSgov/ab2d-events:*",
      "repo:CMSgov/ab2d-lambdas:*",
      "repo:CMSgov/ab2d-properties:*",
      "repo:CMSgov/ab2d-website:*",
      "repo:CMSgov/ab2d:*",
    ]
    bcda = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/bcda-app:*",
      "repo:CMSgov/bcda-ssas-app:*",
      "repo:CMSgov/bcda-static-site:*",
    ]
    dpc = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/dpc-app:*",
      "repo:CMSgov/dpc-static-site:*",
    ]
    cdap = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
    ]
  }
  admin_app = "bcda"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_role" "admin" {
  name = "ct-ado-${local.admin_app}-application-admin"
}

data "aws_iam_policy_document" "github_actions_role_assume" {
  # Allow access from the admin role
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn]
    }
  }

  # Allow access from GitHub-hosted runners via OIDC
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

  # Allow for use as an instance profile for packer, etc.
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "poweruser_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

data "aws_iam_policy_document" "github_actions_role_inline" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.app}-${var.env}-github-actions"
  path = "/delegatedadmin/developer/"

  assume_role_policy = data.aws_iam_policy_document.github_actions_role_assume.json

  permissions_boundary = data.aws_iam_policy.poweruser_boundary.arn

  inline_policy {
    name   = "github-actions"
    policy = data.aws_iam_policy_document.github_actions_role_inline.json
  }
}

resource "aws_iam_instance_profile" "github_actions_role" {
  name = "${var.app}-${var.env}-github-actions"
  path = "/delegatedadmin/developer/"
  role = aws_iam_role.github_actions.name
}
