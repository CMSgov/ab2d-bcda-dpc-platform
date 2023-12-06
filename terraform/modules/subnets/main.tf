data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  dynamic "filter" {
    for_each = var.app_team == "bcda" || var.app_team == "dpc" ? [1] : []
    content {
      name   = "tag:Layer"
      values = [var.layer]
    }
  }
  dynamic "filter" {
    for_each = var.app_team == "ab2d" ? [1] : []
    content {
      name   = "tag:use"
      values = [var.use]
    }
  }
}
