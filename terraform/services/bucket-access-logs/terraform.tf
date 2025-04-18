provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/bucket-access-logs"
      component = "bucket-access-logs"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "bucket-access-logs/terraform.tfstate"
  }
}
