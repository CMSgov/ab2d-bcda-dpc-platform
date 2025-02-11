# Firehose Data Stream
resource "aws_kinesis_firehose_delivery_stream" "ingester_agg" {
  depends_on  = [aws_glue_catalog_table.agg_metric_table]
  name        = "${local.stack_prefix}-ingester_agg"
  destination = "extended_s3"

  extended_s3_configuration {
    bucket_arn          = local.dpc_glue_bucket_arn
    buffering_interval  = 300
    buffering_size      = 128
    error_output_prefix = "databases/${local.agg_profile}/filter_errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"

    prefix      = "databases/${local.agg_profile}/metric_table/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    kms_key_arn = local.dpc_glue_bucket_key_arn

    role_arn           = aws_iam_role.iam-role-firehose.arn
    s3_backup_mode     = "Disabled"
    compression_format = "UNCOMPRESSED" # Must be UNCOMPRESSED when format_conversion is turned on

    cloudwatch_logging_options {
      enabled = false
    }

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${resource.aws_lambda_function.format_dpc_logs.arn}:$LATEST"
        }
      }
    }
  }

  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }
}

resource "aws_glue_catalog_database" "agg" {
  name        = "${local.stack_prefix}-db"
  description = "DPC Aggregation Insights database"
}

resource "aws_glue_security_configuration" "main" {
  name = "${local.stack_prefix}-db-security"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      kms_key_arn        = local.dpc_glue_bucket_key_arn
      s3_encryption_mode = "SSE-KMS"
    }
  }
}

# CloudWatch Log Subscription
resource "aws_cloudwatch_log_subscription_filter" "quicksight-cloudwatch-agg-log-subscription" {
  name = "${local.stack_prefix}-agg-subscription"
  # Set the log group name so that if we use an environment ending in "-dev", it will get logs from
  # the "real" log group for that environment. So we could make an environment "prod-sbx-dev" that
  # we can use for development, and it will read from the "prod-sbx" environment.
  log_group_name  = "/aws/ecs/fargate/dpc-${local.this_env}-aggregation"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.ingester_agg.arn
  role_arn        = aws_iam_role.iam-role-cloudwatch-logs.arn
}
