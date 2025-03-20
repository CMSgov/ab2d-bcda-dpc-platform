## quicksight-related policies and roles
# Allows reads of inputs
resource "aws_iam_policy" "athena_query_source" {
  name        = "dpc-insights-athena-query-src-${var.env}"
  path        = "/delegatedadmin/developer/"
  description = "Rights needed for source athena query access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "s3QueryPolicy"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:ListAllMyBuckets",
          "athena:ListDataCatalogs",
          "athena:GetDataCatalog",
          "quicksight:*"
        ]
        Resource = [
          "arn:aws:s3:::aws-athena-query-results-*",
          local.dpc_glue_bucket_arn,
          "${local.dpc_glue_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CMK"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.dpc_glue_bucket_key_arn
      }
    ]
  })
}

resource "aws_iam_policy" "athena_glue_access" {
  name        = "dpc-insights-athena-glue-access-${var.env}"
  path        = "/delegatedadmin/developer/"
  description = "Permissions needed for Athena to access Glue databases"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabasePermissions"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase"
        ]
        Resource = [
          "arn:aws:glue:us-east-1:${local.account_id}:catalog",
          aws_glue_catalog_database.agg.arn,
          aws_glue_catalog_database.api.arn
        ]
      },
      {
        Sid    = "TablePermissions"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTables"
        ]
        Resource = [
          aws_glue_catalog_database.agg.arn,
          aws_glue_catalog_database.api.arn,
          "arn:aws:glue::${local.account_id}:table/${aws_glue_catalog_database.agg.name}/*",
          "arn:aws:glue::${local.account_id}:table/${aws_glue_catalog_database.api.name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "athena_query_results" {
  name        = "dpc-insights-athena-query-results-${var.env}"
  path        = "/delegatedadmin/developer/"
  description = "Rights needed for results athena query access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "s3QueryResultPolicy"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:ListAllMyBuckets",
          "athena:ListDataCatalogs",
          "athena:GetDataCatalog",
          "quicksight:*"
        ]
        Resource = [
          "arn:aws:s3:::aws-athena-query-results-*",
          local.dpc_athena_bucket_arn,
          "${local.dpc_athena_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CMK"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.dpc_athena_bucket_key_arn
      }
    ]
  })
}

# CloudWatch Role
resource "aws_iam_role" "iam-role-cloudwatch-logs" {
  name        = "${local.stack_prefix}-cloudwatch-logs-role"
  description = "Allows access to the DPC Insights Firehose Delivery Stream and Export to S3"
  path        = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "logs.${data.aws_region.current.name}.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_policy" "cwlogs-firehose" {
  name        = "${local.stack_prefix}-cloudwatch-logs-policy"
  path        = "/delegatedadmin/developer/"
  description = "Rights needed for CW and Firehose"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "firehose:*"
        Effect = "Allow"
        Resource = [
          aws_kinesis_firehose_delivery_stream.ingester_agg.arn,
          aws_kinesis_firehose_delivery_stream.ingester_api.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cwlogs-firehose-attach" {
  role       = aws_iam_role.iam-role-cloudwatch-logs.id
  policy_arn = aws_iam_policy.cwlogs-firehose.arn
}

# Firehose Policy
resource "aws_iam_policy" "iam-policy-firehose" {
  description = "Allow firehose delivery to DPC insights S3 bucket"
  name        = "${local.stack_prefix}-firehose-to-s3-policy"
  path        = "/delegatedadmin/developer/"

  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "glue:GetTable",
            "glue:GetTableVersion",
            "glue:GetTableVersions",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.agg.name}/${aws_glue_catalog_table.agg_metric_table.name}",
            "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.agg.name}",
            "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.api.name}/${aws_glue_catalog_table.api_metric_table.name}",
            "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.api.name}",
            "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog"
          ]
          Sid = "GetGlueTable"
        },
        {
          Action = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject",
          ]
          Effect = "Allow"
          Resource = [
            local.dpc_glue_bucket_arn,
            "${local.dpc_glue_bucket_arn}/*",
          ]
          Sid = "GetS3Bucket"
        },
        {
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ]
          Effect   = "Allow"
          Resource = local.dpc_glue_bucket_key_arn
          Sid      = "UseKMSKey"
        },
        {
          Action = [
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${local.agg_profile}-firehose:log-stream:*",
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${local.api_profile}-firehose:log-stream:*",
          ]
          Sid = "PutLogEvents"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "iam-policy-firehose" {
  role       = aws_iam_role.iam-role-cloudwatch-logs.id
  policy_arn = aws_iam_policy.iam-policy-firehose.arn
}

# Firehose Role
resource "aws_iam_role" "iam-role-firehose" {
  name        = "${local.stack_prefix}-firehose-role"
  description = "allows Firehose access to Lambda transformation"
  path        = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  force_detach_policies = false

  max_session_duration = 3600
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "firehose.amazonaws.com"
          }
          Sid = "FirehoseAssume"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "iam-policy-firehose-role" {
  role       = aws_iam_role.iam-role-firehose.id
  policy_arn = aws_iam_policy.iam-policy-firehose.arn
}

resource "aws_iam_role_policy_attachment" "role-firehose-attach" {
  role       = aws_iam_role.iam-role-firehose.id
  policy_arn = aws_iam_policy.cwlogs-firehose.arn
}

resource "aws_iam_policy" "iam-policy-lambda-firehose" {
  description = "Allow firehose lambda execution"
  name        = "invoke-${aws_lambda_function.format_dpc_logs.function_name}"
  path        = "/delegatedadmin/developer/"

  policy = jsonencode(
    {
      Statement = [
        {
          Action = "lambda:InvokeFunction"
          Effect = "Allow"
          Resource = [
            "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.format_dpc_logs.function_name}",
            "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.format_dpc_logs.function_name}:$LATEST",
          ]
          Sid = "InvokeCW2Json"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "iam-policy-invoke-lambda-firehose" {
  role       = aws_iam_role.iam-role-firehose.id
  policy_arn = aws_iam_policy.iam-policy-lambda-firehose.arn
}


# Lambda Role
resource "aws_iam_role" "iam-role-firehose-lambda" {
  name        = "${local.stack_prefix}-firehose-lambda-role"
  description = "Allow Lambda to create and write to its log group"
  path        = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  max_session_duration  = 3600
  force_detach_policies = false
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_policy" "iam-policy-lambda-firehose-logging" {
  description = "Allow firehose lambda execution logging"
  name        = "${local.stack_prefix}-lambda-logging-policy"
  path        = "/delegatedadmin/developer/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.agg_profile}-cw-to-flattened-json:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.api_profile}-cw-to-flattened-json:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecordBatch",
          "firehose:PutRecord"
        ]
        Resource = [
          "arn:aws:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${local.agg_profile}-ingester_agg",
          "arn:aws:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${local.api_profile}-ingester_api"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam-policy-invoke-lambda-firehose-logging" {
  role       = aws_iam_role.iam-role-firehose-lambda.id
  policy_arn = aws_iam_policy.iam-policy-lambda-firehose-logging.arn
}

# Glue role for Crawler
resource "aws_iam_role" "iam-role-glue" {
  name        = "${local.stack_prefix}-glue-role"
  description = "allows Glue access to S3 database"
  path        = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  force_detach_policies = false

  max_session_duration = 3600
  assume_role_policy = jsonencode(
    {
      Statement = [

        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "glue.amazonaws.com"
          }
          Sid = "GlueAssume"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_policy" "iam-policy-glue-crawler" {
  description = "Allow glue crawler execution"
  name        = "${local.stack_prefix}-glue-crawler-policy"
  path        = "/delegatedadmin/developer/"

  policy = jsonencode({

    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:HeadBucket",
          "s3:GetObject*",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::awsglue-datasets/*",
          "arn:aws:s3:::awsglue-datasets"
        ]
        Sid = "GlueList"
      },
      {
        Action = [
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket",
          "s3:HeadBucket",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          local.dpc_glue_bucket_arn
        ]
        Sid = "s3Buckets"
      },
      {
        Action = [
          "s3:PutObject*",
          "s3:ListMultipartUploadParts",
          "s3:GetObject*",
          "s3:DeleteObject*",
          "s3:AbortMultipartUpload"
        ]
        Effect = "Allow"
        Resource = [
          "${local.dpc_glue_bucket_arn}/*"
        ]
        Sid = "s3Objects"
      },
      {
        Action = [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = local.dpc_glue_bucket_key_arn
        Sid      = "CMK"
      }
    ]
    Version = "2012-10-17"

  })
}

resource "aws_iam_role_policy_attachment" "iam-policy-glue-crawler" {
  role       = aws_iam_role.iam-role-glue.id
  policy_arn = aws_iam_policy.iam-policy-glue-crawler.arn
}

data "aws_iam_policy" "aws_glue_service_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "iam-policy-glue-service" {
  role       = aws_iam_role.iam-role-glue.id
  policy_arn = data.aws_iam_policy.aws_glue_service_role.arn
}

data "aws_iam_policy" "aws_athena_full_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role_policy_attachment" "iam-policy-athena-service" {
  role       = aws_iam_role.iam-role-glue.id
  policy_arn = data.aws_iam_policy.aws_athena_full_policy.arn
}

# Grant to QuickSight access to the Glue bucket key
resource "aws_kms_grant" "glue" {
  name              = "${local.dpc_glue_s3_name}-grant"
  key_id            = local.dpc_glue_bucket_key_id
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/aws-quicksight-service-role-v0"
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey", "DescribeKey", "ReEncryptTo", "ReEncryptFrom"]
}

# Grant to QuickSight access to the Athena bucket key
resource "aws_kms_grant" "athena" {
  name              = "${local.dpc_athena_s3_name}-grant"
  key_id            = local.dpc_athena_bucket_key_id
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/aws-quicksight-service-role-v0"
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey", "DescribeKey", "ReEncryptTo", "ReEncryptFrom"]
}
