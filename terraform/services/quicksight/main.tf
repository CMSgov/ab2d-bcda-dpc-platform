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
