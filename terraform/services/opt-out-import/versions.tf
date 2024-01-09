provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/opt-out-import"
      component = "opt-out-import"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "opt-out-import/terraform.tfstate"
  }
}
