# Terraform for initializing tfstate resources

This terraform creates the S3 buckets for storing terraform state in AWS.

To create the resources with the first run of `terraform init`, comment out the backend block in terraform.tf. This will create a local terraform.tfstate file.

    terraform init
    terraform apply -var app=bcda -var env=mgmt

Once the resources have been created, uncomment the backend block in terraform.tf again and reference a backend config:

    terraform init -backend-config=../../backends/bcda-mgmt.s3.tfbackend

The command should prompt to migrate the state from the local file to the remote backend.
