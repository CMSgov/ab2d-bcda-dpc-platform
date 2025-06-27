locals {
  is_sandbox = contains(["sbx", "sandbox"], var.env)
  ab2d_env_lbs = {
    dev  = "ab2d-dev"
    test = "ab2d-east-impl"
    sbx  = "ab2d-sbx-sandbox"
    prod = "api-ab2d-east-prod"
  }
  load_balancers = {
    ab2d = "ab2d-${var.env}-api"
    bcda = "bcda-api-${var.env}-01"
    dpc  = "dpc-${var.env}-1"
  }
}

data "aws_lb" "api" {
  name = local.load_balancers[var.app]
}

data "aws_wafv2_ip_set" "external_services" {
  count = local.is_sandbox ? 0 : 1
  name  = "external-services"
  scope = "REGIONAL"
}

resource "aws_wafv2_ip_set" "api_customers" {
  count              = local.is_sandbox ? 0 : 1
  name               = "${var.app}-${var.env}-api-customers"
  description        = "IP ranges for customers of this API"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  # Addresses will be managed outside of terraform.
  addresses = []

  lifecycle {
    ignore_changes = [
      addresses,
    ]
  }
}

resource "aws_wafv2_ip_set" "ipv6_api_customers" {
  count              = local.is_sandbox ? 0 : 1
  name               = "${var.app}-${var.env}-ipv6-api-customers"
  description        = "IP ranges for customers of this API"
  scope              = "REGIONAL"
  ip_address_version = "IPV6"

  # Addresses will be managed outside of terraform.
  addresses = []

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
  rate_limit              = var.app == "bcda" ? 1000 : 3000
  ip_sets = local.is_sandbox ? [] : [
    one(data.aws_wafv2_ip_set.external_services).arn,
    one(aws_wafv2_ip_set.api_customers).arn,
    one(aws_wafv2_ip_set.ipv6_api_customers).arn,
  ]
}
