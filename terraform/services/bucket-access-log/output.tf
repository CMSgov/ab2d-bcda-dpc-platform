output "name" {
  description = "The name of the S3 bucket used for bucket access logs"
  value       = aws_s3_bucket.bucket_access_logs.bucket
}
