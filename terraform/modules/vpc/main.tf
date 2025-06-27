data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["${var.app}-east-${var.env}"]
  }
}
