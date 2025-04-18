provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/opt-out-import"
      component   = "opt-out-import"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "opt-out-import/terraform.tfstate"
  }
}
