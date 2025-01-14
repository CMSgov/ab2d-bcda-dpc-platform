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

data "aws_lb" "api" {
  name = local.load_balancers[var.app]
}

data "aws_wafv2_ip_set" "external_services" {
  count = var.env == "sbx" ? 0 : 1
  name  = "external-services"
  scope = "REGIONAL"
}

resource "aws_wafv2_ip_set" "api_customers" {
  count              = var.env == "sbx" ? 0 : 1
  name               = "${var.app}-${var.env}-api-customers"
  description        = "IP ranges for customers of this API"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  # Addresses will be managed outside of terraform. This is
  # a placeholder address for all apps/environments.
  # See: https://confluence.cms.gov/x/UDs2Q
  addresses = ["203.0.113.0/32"]

  lifecycle {
    ignore_changes = [
      addresses,
    ]
  }
}

module "aws_waf" {
  source = "../../modules/firewall"

  app  = var.app
  env  = var.env
  name = "${var.app}-${var.env}-api"

  scope        = "REGIONAL"
  content_type = "APPLICATION_JSON"

  associated_resource_arn = data.aws_lb.api.arn
  ip_sets = var.env == "sbx" ? [] : [
    one(data.aws_wafv2_ip_set.external_services).arn,
    one(aws_wafv2_ip_set.api_customers).arn,
  ]
}
