locals {
  name = "${var.app}-${var.env}-tfstate"
}

module "tfstate_bucket" {
  source = "../../modules/bucket"
  name   = local.name
  legacy = var.legacy
}

module "tfstate_table" {
  source = "../../modules/table"
  name   = local.name
  count  = var.legacy == true ? 1 : 0
}

moved {
  from = module.tfstate_table
  to   = module.tfstate_table[0]
}
