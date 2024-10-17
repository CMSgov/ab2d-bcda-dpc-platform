provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "github-actions"
      Terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "github-actions/terraform.tfstate"
  }
  required_version = "~> 1.5.5"
}
