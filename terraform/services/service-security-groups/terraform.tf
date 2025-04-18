provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/service-security-groups"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "service-security-groups/terraform.tfstate"
  }
}
