provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/access-log"
      component = "access-log"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "access-log/terraform.tfstate"
  }
}