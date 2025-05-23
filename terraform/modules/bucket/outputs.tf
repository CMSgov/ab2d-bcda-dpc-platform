output "arn" {
  description = "ARN for the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "id" {
  description = "ID for the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "key_alias" {
  description = "Key Alias for this bucket"
  value       = module.bucket_key.alias
}

output "key_arn" {
  description = "KEY ARN for this bucket"
  value       = module.bucket_key.arn
}

output "key_id" {
  description = "KEY identifier for this bucket"
  value       = module.bucket_key.id
}
