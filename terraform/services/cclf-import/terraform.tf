provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/cclf-import"
      component   = "cclf-import"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "cclf-import/terraform.tfstate"
  }
}
