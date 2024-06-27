resource "aws_s3_bucket" "bucket_access_logs" {
  bucket        = "${var.app}-${var.env}-bucket-access-log"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
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
      "arn:aws:s3:::${aws_s3_bucket.bucket_access_logs.bucket}/${local.s3_logs_prefix}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id
  policy = data.aws_iam_policy_document.bucket_access_logs.json
}
