provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/opt-out-export"
      component   = "opt-out-export"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "opt-out-export/terraform.tfstate"
  }
}
