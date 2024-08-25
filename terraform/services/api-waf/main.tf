locals {
  ab2d_env_lbs = {
    dev  = "ab2d-dev"
    test = "ab2d-east-impl"
    sbx  = "ab2d-sbx-sandbox"
    prod = "api-ab2d-east-prod"
  }
  load_balancers = {
    ab2d = "${local.ab2d_env_lbs[var.env]}"
    bcda = "bcda-api-${var.env == "sbx" ? "opensbx" : var.env}-01"
    dpc  = "dpc-${var.env == "sbx" ? "prod-sbx" : var.env}-1"
  }
}

data "aws_lb" "api_lb" {
  name = local.load_balancers[var.app]
}

module "aws_waf" {
  source = "../../modules/firewall"

  app             = var.app
  env             = var.env
  name            = "${var.app}-api-waf"
  aws_lb_arn      = data.aws_lb.api_lb.arn
  rate_based_rule = var.rate_based_rule
  ip_sets_rule    = var.ip_sets_rule
  scope           = "REGIONAL"
}
