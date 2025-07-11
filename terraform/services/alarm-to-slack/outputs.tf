output "function_role_arn" {
  value = module.sns_to_slack_function.role_arn
}

output "sqs_queue_arn" {
  value = module.sns_to_slack_queue.arn
}

output "zip_bucket" {
  value = module.sns_to_slack_function.zip_bucket
}
