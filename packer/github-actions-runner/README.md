# GitHub Actions runner packer

These scripts build the images for self-hosted GitHub Actions runners, extending gold images from CMS Cloud.

## Usage

This packer build is generally run by the [GitHub Actions runner images](/.github/workflows/github-actions-runner-images.yml) workflow in this repo. To run and debug locally, ensure the [session-manager-plugin is installed](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-verify.html) and create a variables.pkrvars.hcl in this directory as follows:

```
ami_account = "xxxxxxxxxxxx" # bcda
s3_tarball  = "s3://xxxxxxxxxxxxxxxxxxxxxx/actions-runner-linux.tar.gz"
vpc_id      = "vpc-xxxxxxxxxxxxxxx"    # bcda-managed-vpc
subnet_id   = "subnet-xxxxxxxxxxxxxxx" # bcda-managed-az2-app

# Security groups necessary for Trend Micro and internet access
security_group_ids = ["sg-xxxxxxxxxxxxxx", "sg-xxxxxxxxxxxxxxx"]
```

Then get short-term access keys for AWS and run these packer commands in this directory:

```
packer init .
packer build -var-file=variables.pkrvars.hcl -debug .
```
