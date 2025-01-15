identifier_suffix = ""

/* DB - Database */
vpc_id            = var.vpc_id # data.aws_vpc.main.id
app               = "bcda"
env               = var.env
multi_az          = true
iops              = 1000
storage_type      = "io1"
allocated_storage = 100
instance_class = "db.m6i.large"
engine_version = "11"
additional_ingress_sgs = flatten([
  aws_security_group.worker_sg.id, # data "aws_security_group" { name=bcda-worker-${var.env} }
  aws_security_group.app_sg.id, # data "aws_security_group" { name=bcda-api-${var.env} }
  data.aws_security_group.jenkins_sg.id, # data "aws_security_group" { name=allow_elb }
])
gdit_security_group_ids = flatten(data.aws_security_group.gedit.ids)
data_subnets            = data.aws_subnet_ids.data_subnets.ids # 
#app_db_pw               = var.app_db_pw - deprecated, we're managing this in SM
cpm_backup              = "Daily Weekly Monthly"

/* DB - Route53 */
resource "aws_route53_record" "rds" {
  zone_id = aws_route53_zone.local_zone.zone_id
  name    = "rds"
  type    = "CNAME"
  ttl     = "300"
  records = [module.database.address]
}

resource "aws_route53_zone" "local_zone" {
  name = "bcda-${var.env}.local"

  vpc {
    vpc_id = data.aws_vpc.main.id
  }
}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["bcda-${var.env}-vpc"]
  }
}

data "aws_subnet_ids" "data_subnets" {
  vpc_id = data.aws_vpc.main.id

  tags    = {
    Layer = "data"
  }
}

gedit_security_group_names = [
  "bcda-${var.env}-vpn-private"  
  "bcda-${var.env}-vpn-public"
  "bcda-${var.env}-remote-management"
  "bcda-${var.env}-enterprise-tools"
]

data "aws_security_group" "gedit" {
  for_each = local.gedit_security_group_names

  name = each.value
}

data "aws_secretsmanager_secret" "database_secret" {
  name = "bcda/${local.db_name}/rds-main-credentials"
  #resolve after migrating passwords to secrets manager
}

additional_ingress_groups = [
  "bcda-worker-${var.env}"
  "bcda-api-${var.env}"
  "allow-elb"
]

data "aws_security_group" "additional_ingress" { 
  for_each = local.additional_ingress_sgs

  name = each.value
}
