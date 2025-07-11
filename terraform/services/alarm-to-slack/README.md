# Terraform for alarm-to-slack function and associated infra

This service sets up the infrastructure for the alarm-to-slack lambda function in upper and lower environments for DPC

## Updating the lambda code

The executable for this lambda is in lambda_src. It must pass both pylint and pytest checks.

If you want to see the log messages, you can run pytest with the -s flag.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
AWS_REGION=us-east-1 terraform init -backend-config=../../backends/dpc-dev-gf.s3.tfbackend
AWS_REGION=us-east-1 terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the tf-alarm-to-slack-apply.yml workflow.
