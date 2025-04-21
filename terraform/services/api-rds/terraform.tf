provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/api-rds"
      component   = "api-rds"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "api-rds/terraform.tfstate"
  }
}
