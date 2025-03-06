locals {
  stack_prefix = "${var.app}-${local.this_env}"
  this_env     = var.env == "sbx" ? "prod-sbx" : var.env
  account_id   = data.aws_caller_identity.current.account_id
  agg_profile  = "${local.stack_prefix}-aggregator"
  api_profile  = "${local.stack_prefix}-api"

  athena_profile = "${var.app}_${local.this_env}_insights_${local.account_id}"
  athena_prefix  = "${var.app}-${local.this_env}-insights"

  dpc_glue_s3_name    = "${local.stack_prefix}-${local.account_id}"
  dpc_athena_s3_name  = local.athena_prefix

  dpc_glue_bucket_arn         = module.dpc_insights_data.arn
  dpc_glue_bucket_key_alias   = module.dpc_insights_data.key_alias
  dpc_glue_bucket_key_arn     = module.dpc_insights_data.key_arn
  dpc_athena_bucket_arn       = module.dpc_insights_athena.arn
  dpc_athena_bucket_key_alias = module.dpc_insights_athena.key_alias
  dpc_athena_bucket_key_arn   = module.dpc_insights_athena.key_arn
  dpc_athena_bucket_id        = module.dpc_insights_data.id

  athena_workgroup_name         = local.athena_prefix
  dpc_athena_results_folder_key = "workgroups/${local.athena_workgroup_name}/"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "dpc_insights_data" {
  source = "../../modules/bucket"
  name   = local.dpc_glue_s3_name
}

module "dpc_insights_athena" {
  source = "../../modules/bucket"
  name   = local.dpc_athena_s3_name
}

resource "aws_s3_object" "folder" {
  bucket       = module.dpc_insights_athena.id
  content_type = "application/x-directory"
  key          = local.dpc_athena_results_folder_key
}
