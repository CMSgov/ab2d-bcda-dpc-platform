locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"
  # Whether to send messages when state returns to OK
  ignore_ok = {
    "dpc" = "true"
  }
}

data "aws_ssm_parameter" "slack_webhook_url" {
  name = "/${var.app}/lambda/slack_webhook_url"
}

module "sns_to_slack_function" {
  source = "../../modules/function"

  app    = var.app
  env    = var.env
  legacy = false

  name        = local.full_name
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  environment_variables = {
    ENV               = var.env
    APP_NAME          = "${var.app}-${var.env}-alarm-to-slack"
    SLACK_WEBHOOK_URL = data.aws_ssm_parameter.slack_webhook_url.value
    IGNORE_OK         = local.ignore_ok[var.app]
  }
}

# Set up queue for receiving messages when a cloudwatch alert is sent
data "aws_sns_topic" "cloudwatch" {
  name = "${var.app}-${var.env}-cloudwatch-alarms"
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.sns_to_slack_function.name
  sns_topic_arn = data.aws_sns_topic.cloudwatch.arn
}
