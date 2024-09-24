# Terraform for service security groups

This terraform service creates and manages security groups for various services. Currently included:

- access from public and private Zscaler (ingress CIDRs managed outside of terraform)
- access to the internet (http and https)

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
