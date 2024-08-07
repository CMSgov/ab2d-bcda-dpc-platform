provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/api-waf"
      component   = "api-waf"
      environment = var.env
      terraform   = true
    }
  }
}
