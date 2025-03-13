provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/quicksight"
      component   = "quicksight"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "quicksight/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
  required_version = "~> 1.5"
}
