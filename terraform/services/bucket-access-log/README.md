# Terraform for bucket-access-logs in target accounts

This terraform code manages an s3 bucket in each target account (prod and non-prod) for logging access to other S3 buckets.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
