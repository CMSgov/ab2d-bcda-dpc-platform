data "aws_caller_identity" "current" {}

module "bucket_key" {
  source      = "../key"
  name        = "${var.name}-bucket"
  description = "For ${var.name} S3 bucket and its access logs"
  user_roles  = var.cross_account_read_roles
}

resource "aws_s3_bucket" "this" {
  bucket        = var.legacy == true ? var.name : null
  bucket_prefix = var.legacy == false ? "${var.name}-" : null
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "AllowSSLRequestsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Bucket policy to allow promotion of artifacts by deploy roles in upper environments
  dynamic "statement" {
    for_each = length(var.cross_account_read_roles) > 0 ? [1] : []
    content {
      sid = "CrossAccountRead"

      principals {
        type        = "AWS"
        identifiers = var.cross_account_read_roles
      }

      actions = [
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionTagging",
        "s3:ListBucket",
      ]

      resources = [
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.bucket_key.id
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_iam_account_alias" "current" {}

data "aws_s3_bucket" "bucket_access_logs" {
  bucket = (var.legacy == true ? "${data.aws_caller_identity.current.account_id}-bucket-access-logs" :
    data.aws_iam_account_alias.current.account_alias == "aws-cms-oeda-bcda-prod" ? "bucket-access-logs-20250411172631068600000001" :
      var.name)
}

resource "aws_s3_bucket_logging" "this" {
  bucket = aws_s3_bucket.this.bucket

  target_bucket = data.aws_s3_bucket.bucket_access_logs.bucket
  target_prefix = "${var.name}/"
}
