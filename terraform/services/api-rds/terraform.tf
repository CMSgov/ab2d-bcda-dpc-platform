provider "aws" {
  default_tags {
    tags = module.platform.default_tags
  }
}

terraform {
  backend "s3" {
    key = "api-rds/terraform.tfstate"
  }
}
