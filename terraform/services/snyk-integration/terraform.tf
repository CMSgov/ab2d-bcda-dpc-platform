provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/snyk-integration"
      component = "snyk"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "snyk-integration/terraform.tfstate"
  }
}
