module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=0bd3eeae6b03cc8883b7dbdee5f04deb33468260"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/kms-keys"
  service     = "kms-keys"
}

locals {
  env                              = module.standards.env
  app                              = module.standards.app
  account_id                       = module.standards.account_id
  kms_default_deletion_window_days = 30
  key_alias                        = "alias/${local.app}-${local.env}"
}

data "aws_iam_policy_document" "default_kms_key_policy" {
  statement {
    sid    = "AllowKeyManagement"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "data" {
  # Allow cloudwatch to use the key to decrypt data
  statement {
    sid    = "AllowCloudWatchKeyUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  # Allow CloudFront to use the key to decrypt data
  statement {
    sid    = "AllowCloudfrontKeyUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSNSKeyUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSQSKeyUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  # Allow cloudwatch logs to use the key to encrypt/decrypt data
  statement {
    sid    = "AllowCloudWatchLogsKeyUsage"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.us-east-1.amazonaws.com",
        "logs.us-west-2.amazonaws.com"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  # Allow S3 to work with encrypted queues and topics
  statement {
    sid    = "AllowS3KeyUsage"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "s3.amazonaws.com"
      ]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEventsKeyUsage"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com"
      ]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }

  # Allow ECS Fargate to generate a data key and describe the key
  statement {
    sid    = "AllowECSFargateKeyUsage"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "fargate.amazonaws.com"
      ]
    }
    actions = [
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  # Allow ECS Fargate to create grants for a given key
  statement {
    sid    = "AllowECSFargateKeyGrants"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "fargate.amazonaws.com"
      ]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "kms:GrantOperations"
      values   = ["Decrypt"]
    }
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
  }
}


data "aws_iam_policy_document" "combined" {
  source_policy_documents = [
    data.aws_iam_policy_document.default_kms_key_policy.json,
    data.aws_iam_policy_document.data.json
  ]
}

resource "aws_kms_key" "primary" {
  bypass_policy_lockout_safety_check = false
  deletion_window_in_days            = local.kms_default_deletion_window_days
  description                        = "Primary ${local.app} ${local.env} CMK"
  enable_key_rotation                = true
  is_enabled                         = true
  multi_region                       = false
  policy                             = data.aws_iam_policy_document.combined.json
  rotation_period_in_days            = 365

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "primary" {
  name          = local.key_alias
  target_key_id = aws_kms_key.primary.id
}

resource "aws_kms_key" "secondary" {
  provider                           = aws.secondary
  bypass_policy_lockout_safety_check = false
  deletion_window_in_days            = local.kms_default_deletion_window_days
  description                        = "Secondary ${local.app} ${local.env} CMK"
  enable_key_rotation                = true
  is_enabled                         = true
  multi_region                       = false
  policy                             = data.aws_iam_policy_document.combined.json
  rotation_period_in_days            = 365

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "secondary" {
  provider      = aws.secondary
  name          = local.key_alias
  target_key_id = aws_kms_key.secondary.id
}
