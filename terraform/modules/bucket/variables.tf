variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list(any)
  default     = []
}

variable "bucket_key_enabled" {
  description = "When true, encrypt objects with [AWS S3 Bucket Key](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)"
  type        = bool
  default     = false
}
