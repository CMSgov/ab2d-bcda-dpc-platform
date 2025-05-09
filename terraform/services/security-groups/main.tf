locals {
  stdenv = (
    var.app == "bcda" ? (var.env == "sbx" ? "opensbx" : var.env) :
    var.app == "dpc" ? (var.env == "sbx" ? "prod-sbx" : var.env) :
    var.env
  )
}

data "aws_ssm_parameter" "cdap_mgmt_vpc_cidr" {
  count = var.legacy ? 0 : 1

  name = "/cdap/mgmt-vpc/cidr"
}

module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
  legacy = var.legacy
}

resource "aws_security_group" "zscaler_public" {
  name        = var.legacy ? "${var.app}-${var.env}-allow-zscaler-public" : "zscaler-public"
  description = "Allow public zscaler traffic"
  vpc_id      = module.vpc.id
  tags = {
    Name = var.legacy ? "${var.app}-${var.env}-allow-zscaler-public" : "zscaler-public"
  }
}

resource "aws_security_group" "zscaler_private" {
  name        = var.legacy ? "${var.app}-${var.env}-allow-zscaler-private" : "zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
  tags = {
    Name = var.legacy ? "${var.app}-${var.env}-allow-zscaler-private" : "zscaler-private"
  }
}

resource "aws_security_group" "internet" {
  name        = var.legacy ? "${var.app}-${var.env}-internet" : "internet"
  description = "Allow access to the internet"
  vpc_id      = module.vpc.id
  tags = {
    Name = var.legacy ? "${var.app}-${var.env}-internet" : "internet"
  }
}

resource "aws_vpc_security_group_egress_rule" "internet_http" {
  security_group_id = aws_security_group.internet.id

  description = "Allow http access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "internet_https" {
  security_group_id = aws_security_group.internet.id

  description = "Allow https access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_security_group" "remote_management" {
  count       = var.legacy ? 0 : 1
  name        = "remote-management"
  description = "Allow access from remote management VPC"
  vpc_id      = module.vpc.id
  tags = {
    Name = "remote-management"
  }
}

resource "aws_vpc_security_group_ingress_rule" "remote_management_allow_all" {
  count             = var.legacy ? 0 : 1
  security_group_id = aws_security_group.remote_management[0].id

  description = "Allow all traffic from CDAP management VPC"
  cidr_ipv4   = data.aws_ssm_parameter.cdap_mgmt_vpc_cidr[0].value
  ip_protocol = -1
}
