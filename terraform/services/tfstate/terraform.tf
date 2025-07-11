provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tfstate"
    }
  }
}

terraform {
  # Comment out backend block and init without -backend-config for initial creation of resources
  backend "s3" {
    key = "tfstate/terraform.tfstate"
  }
}
