provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/github-actions-role"
      component = "github-actions"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "github-actions-role/terraform.tfstate"
  }
}
