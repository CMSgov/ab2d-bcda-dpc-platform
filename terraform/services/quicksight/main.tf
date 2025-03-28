locals {
  stack_prefix = "${var.app}-${local.this_env}"
  this_env     = var.env == "sbx" ? "prod-sbx" : var.env
  account_id   = data.aws_caller_identity.current.account_id
  agg_profile  = "${local.stack_prefix}-aggregator"
  api_profile  = "${local.stack_prefix}-api"

  athena_profile = replace("${local.stack_prefix}_insights_${local.account_id}", "-", "_")
  athena_prefix  = "${local.stack_prefix}-insights"

  # TODO: Generalize all of the `dpc` prefixing of resources, variables, etc
  dpc_glue_s3_name   = "${local.stack_prefix}-${local.account_id}"
  dpc_athena_s3_name = local.athena_prefix

  dpc_glue_bucket_arn       = module.dpc_insights_data.arn
  dpc_glue_bucket_key_id    = module.dpc_insights_data.key_id
  dpc_glue_bucket_key_arn   = module.dpc_insights_data.key_arn
  dpc_athena_bucket_arn     = module.dpc_insights_athena.arn
  dpc_athena_bucket_key_id  = module.dpc_insights_athena.key_id
  dpc_athena_bucket_key_arn = module.dpc_insights_athena.key_arn
  dpc_athena_bucket_id      = module.dpc_insights_data.id

  athena_workgroup_name         = local.athena_prefix
  dpc_athena_results_folder_key = "workgroups/${local.athena_workgroup_name}/"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "dpc_insights_data" {
  source = "../../modules/bucket"

  name               = local.dpc_glue_s3_name
  bucket_key_enabled = true
}

module "dpc_insights_athena" {
  source = "../../modules/bucket"

  name               = local.dpc_athena_s3_name
  bucket_key_enabled = true
}

resource "aws_s3_object" "folder" {
  bucket       = module.dpc_insights_athena.id
  content_type = "application/x-directory"
  key          = local.dpc_athena_results_folder_key
}

locals {
  kms_key_arn = module.dpc_insights_data.key_arn

  cloudtamer_iam_path = "/delegatedadmin/developer/"
  lambda_full_name    = "${local.stack_prefix}-trigger-glue-crawler"

  glue_crawler_name = aws_glue_crawler.agg_metrics.name
  glue_database     = aws_glue_catalog_database.agg.name
  glue_table        = aws_glue_catalog_table.agg_metric_table.name
  glue_crawler_arn  = aws_glue_crawler.agg_metrics.arn
}

resource "aws_lambda_permission" "this" {
  statement_id   = "${local.lambda_full_name}-allow-s3"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.arn
  principal      = "s3.amazonaws.com"
  source_arn     = module.dpc_insights_data.arn
  source_account = local.account_id
}

resource "aws_lambda_function" "this" {
  function_name = local.lambda_full_name

  description = join("", [
    "Triggers the ${local.glue_crawler_name} Glue Crawler to run when new parquet files are uploaded ",
    "to the API requests' Glue Table path in S3 if the file is part of a new partition."
  ])

  tags = {
    Name = local.lambda_full_name
  }

  kms_key_arn = local.kms_key_arn

  filename         = data.archive_file.lambda_src.output_path
  source_code_hash = data.archive_file.lambda_src.output_base64sha256
  architectures    = ["x86_64"]
  handler          = "trigger_glue_crawler.handler"
  memory_size      = 128
  package_type     = "Zip"
  runtime          = "python3.11"
  timeout          = 520 # 520 seconds gives enough time for backoff retries to be attempted
  environment {
    variables = {
      CRAWLER_NAME       = local.glue_crawler_name
      GLUE_DATABASE_NAME = local.glue_database
      GLUE_TABLE_NAME    = local.glue_table
    }
  }

  role = aws_iam_role.this.arn
}

data "archive_file" "lambda_src" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/trigger_glue_crawler.py"
  output_path = "${path.module}/lambda_src/trigger_glue_crawler.zip"
}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

#iam.tf
resource "aws_iam_policy" "glue" {
  name = "${local.lambda_full_name}-glue"
  path = local.cloudtamer_iam_path
  description = join("", [
    "Permissions for the ${local.lambda_full_name} Lambda to start the ${local.glue_crawler_name} ",
    "Glue crawler and to query specific partitions on the ${local.glue_table} Glue Table"
  ])
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "glue:StartCrawler",
      "Resource": "${local.glue_crawler_arn}"
    },
    {
      "Effect": "Allow",
      "Action": "glue:GetPartition",
      "Resource": [
        "arn:aws:glue:us-east-1:${local.account_id}:catalog",
        "arn:aws:glue:us-east-1:${local.account_id}:database/${local.glue_database}",
        "arn:aws:glue:us-east-1:${local.account_id}:table/${local.glue_database}/${local.glue_table}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "logs" {
  name = "${local.lambda_full_name}-logs"
  path = local.cloudtamer_iam_path
  description = join("", [
    "Permissions for the ${local.lambda_full_name} Lambda to write to its corresponding CloudWatch ",
    "Log Group and Log Stream"
  ])
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:aws:logs:us-east-1:${local.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": [
        "arn:aws:logs:us-east-1:${local.account_id}:log-group:/aws/lambda/${local.lambda_full_name}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "this" {
  name                 = local.lambda_full_name
  path                 = local.cloudtamer_iam_path
  permissions_boundary = data.aws_iam_policy.permissions_boundary.arn
  description          = "Role for ${local.lambda_full_name} Lambda"

  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF

  managed_policy_arns = [
    aws_iam_policy.logs.arn,
    aws_iam_policy.glue.arn
  ]
}

resource "aws_s3_bucket_notification" "agg" {
  bucket = module.dpc_insights_data.id

  lambda_function {
    events = [
      "s3:ObjectCreated:*",
    ]
    filter_prefix       = "databases/dpc-${local.this_env}-aggregator/metric_table/"
    id                  = aws_lambda_function.this.function_name
    lambda_function_arn = aws_lambda_function.this.arn
  }
}
