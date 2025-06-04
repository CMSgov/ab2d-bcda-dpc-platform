data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bucket_access_logs" {
  bucket        = var.legacy == true ? "${data.aws_caller_identity.current.account_id}-bucket-access-logs" : null
  bucket_prefix = var.legacy == false ? "bucket-access-logs-" : null
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_kms_key" "managed_s3" {
  key_id = "alias/aws/s3"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_kms_key.managed_s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "bucket_access_logs" {
  statement {
    sid = "AllowSSLRequestsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.bucket_access_logs.arn,
      "${aws_s3_bucket.bucket_access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid = "S3ServerAccessLogsPolicy"

    effect = "Allow"

    principals {
      identifiers = ["logging.s3.amazonaws.com"]
      type        = "Service"
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.bucket_access_logs.bucket}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id
  policy = data.aws_iam_policy_document.bucket_access_logs.json
}
