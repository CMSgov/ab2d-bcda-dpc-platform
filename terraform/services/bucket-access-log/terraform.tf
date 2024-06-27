provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/bucket-access-log"
      component   = "bucket-access-log"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "bucket-access-log/terraform.tfstate"
  }
}
