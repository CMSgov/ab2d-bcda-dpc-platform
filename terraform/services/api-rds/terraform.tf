provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/api-rds"
      component   = "api-rds"
      environment = var.env
      terraform   = true
      contact     = "ab2d-ops@semanticbits.com"
    }
  }
}

terraform {
  backend "s3" {
    key = "api-rds/terraform.tfstate"
  }
}
