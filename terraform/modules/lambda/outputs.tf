output "function_name" {
  description = "Name for the lambda function"
  value = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "ARN of the IAM role for the lambda"
  value       = aws_iam_role.lambda.arn
}

output "zip_bucket" {
  description = "Bucket name for the function.zip file"
  value       = module.zip_bucket.id
}
