locals {
  ab2d_env_lbs = {
    dev  = "ab2d-dev"
    test = "ab2d-east-impl"
    prod = "api-ab2d-east-prod"
  }
  load_balancers = {
    ab2d = {
      name = "${local.ab2d_env_lbs[var.env]}"
    }
    bcda = {
      name = "${var.app}-api-${var.env}-01"
    }
    dpc = {
      name = "${var.app}-${var.env}-1"
    }
  }
}

data "aws_lb" "api_lb" {
  name = local.load_balancers[var.app].name
}

module "aws_waf" {
  source = "../../modules/firewall"

  app             = var.app
  env             = var.env
  name            = "${var.app}-api-waf"
  aws_lb_arn      = data.aws_lb.api_lb.arn
  rate_based_rule = var.rate_based_rule
  ip_sets_rule    = var.ip_sets_rule
  region          = "us-east-1"
  scope           = var.app == "dpc" ? "CLOUDFRONT" : "REGIONAL"
}
