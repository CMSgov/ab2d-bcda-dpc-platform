module "platform" {
  source = "git::https://github.com/CMSgov/cdap.git//terraform/modules/platform?ref=80d2d5e500bcf8a069386dee677404033af7782c"

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/api-rds"
  service     = "api-rds"
}

locals {
  db_name = "${var.app}-${var.env}"
  sg_name = "${var.app}-${var.env}-db"

  instance_class = {
    ab2d = "db.m6i.2xlarge"
    bcda = (var.env == "sandbox" || var.env == "prod") ? "db.m6i.xlarge" : "db.m6i.large"
    dpc  = "db.m6i.large" # node_type for instance class
  }[var.app]

  allocated_storage = {
    ab2d = 500
    bcda = 100
    dpc  = 20
  }[var.app]

  backup_retention_period = {
    ab2d = 7
    bcda = 35
    dpc  = 21 # 3 ETL periods instead of the default 7 days
  }[var.app]

  quicksight_cidr_blocks = var.app != "ab2d" && length(data.aws_ssm_parameter.quicksight_cidr_blocks) > 0 ? jsondecode(data.aws_ssm_parameter.quicksight_cidr_blocks[0].value) : []

  dpc_specific_tags = {
    Layer       = "data"
    State       = "persistent"
    Environment = var.env
  }
}

# Create database security group
resource "aws_security_group" "sg_database" {
  name = local.sg_name
  description = var.app == "ab2d" ? "${local.db_name} database security group" : (
  var.app == "dpc" ? "Security group for DPC DB" : "App ELB security group")

  vpc_id = module.platform.vpc_id

  tags = {
    Name = local.sg_name,
  }
}


resource "aws_vpc_security_group_egress_rule" "egress_all" {
  security_group_id = aws_security_group.sg_database.id

  description = "Allow all egress"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_ingress_rule" "db_access_from_controller" {
  count                        = var.app == "ab2d" ? 1 : 0
  description                  = "Controller Access"
  from_port                    = "5432"
  to_port                      = "5432"
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.controller_security_group_id[count.index].id
  security_group_id            = aws_security_group.sg_database.id
}

resource "aws_vpc_security_group_ingress_rule" "db_access_from_mgmt" {
  count             = (var.app == "ab2d" || var.app == "dpc") ? 1 : 0
  description       = "Management VPC Access"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = var.mgmt_vpc_cidr
  security_group_id = aws_security_group.sg_database.id
}

resource "aws_vpc_security_group_ingress_rule" "runner_access" {
  count                        = var.app == "bcda" ? 1 : 0
  description                  = "GitHub Actions runner access"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.sg_database.id
  referenced_security_group_id = data.aws_security_group.github_runner[count.index].id
}

resource "aws_vpc_security_group_ingress_rule" "quicksight" {
  count             = var.app != "ab2d" ? length(local.quicksight_cidr_blocks) : 0
  description       = "Allow inbound traffic from AWS QuickSight"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.sg_database.id
  cidr_ipv4         = local.quicksight_cidr_blocks[count.index]
}

# Create database subnet group
resource "aws_db_subnet_group" "subnet_group" {
  name = var.app == "ab2d" ? "${local.db_name}-rds-subnet-group" : (
    var.app == "bcda" && var.env == "sandbox" ? "${var.app}-${var.env}-rds-subnets" : (
  var.app == "dpc" ? "${var.app}-${var.env}-rds-subnet" : "${var.app}-${var.env}-rds-subnets"))

  subnet_ids = data.aws_subnets.db.ids

  tags = {}
}

# Create database parameter group

resource "aws_db_parameter_group" "v16_parameter_group" {
  count  = var.app == "ab2d" ? 1 : 0
  name   = "${local.db_name}-rds-parameter-group-v16"
  family = "postgres16"

  parameter {
    name         = "backslash_quote"
    value        = "safe_encoding"
    apply_method = "immediate"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_cron"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "cron.database_name"
    value        = var.app == "ab2d" && var.env == "test" ? "impl" : var.env
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "statement_timeout"
    value        = "1200000"
    apply_method = "immediate"
  }
  parameter {
    name         = "rds.logical_replication"
    value        = 0
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create database instance
resource "aws_db_instance" "api" {
  allocated_storage   = local.allocated_storage
  engine              = "postgres"
  engine_version      = 16.4
  instance_class      = local.instance_class
  identifier          = local.db_name
  storage_encrypted   = true
  deletion_protection = true

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]
  skip_final_snapshot                   = true
  snapshot_identifier                   = var.snapshot
  final_snapshot_identifier             = var.app == "dpc" ? "dpc-${var.env}-${var.name}-20190829-final" : null
  auto_minor_version_upgrade            = var.app == "dpc" ? true : null
  allow_major_version_upgrade           = var.app == "bcda" ? true : null
  db_subnet_group_name                  = aws_db_subnet_group.subnet_group.name
  parameter_group_name                  = var.app == "ab2d" ? aws_db_parameter_group.v16_parameter_group[0].name : null
  backup_retention_period               = local.backup_retention_period
  iops                                  = var.app == "bcda" ? "1000" : var.app == "dpc" ? "0" : local.db_name == "ab2d-east-prod" ? "20000" : "5000"
  apply_immediately                     = true
  max_allocated_storage                 = var.app == "bcda" ? "1000" : (var.app == "dpc" ? "100" : null)
  storage_type                          = var.app == "dpc" ? "gp2" : null
  monitoring_interval                   = var.app == "dpc" ? 60 : null
  monitoring_role_arn                   = var.app == "dpc" ? data.aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled          = var.app == "dpc" ? true : null
  performance_insights_retention_period = var.app == "dpc" ? 7 : null
  backup_window                         = var.app == "dpc" || var.app == "bcda" ? "05:00-05:30" : null #1 am EST
  copy_tags_to_snapshot                 = var.app == "bcda" || var.app == "dpc" ? true : false
  kms_key_id                            = (var.app == "ab2d" || var.app == "dpc") ? data.aws_kms_alias.main_kms[0].target_key_arn : data.aws_kms_alias.default_rds.target_key_arn
  multi_az                              = var.env == "prod" ? true : false
  vpc_security_group_ids = [
    aws_security_group.sg_database.id,
    module.platform.security_groups["cmscloud-security-tools"].id,
    module.platform.security_groups["remote-management"].id,
    module.platform.security_groups["zscaler-private"].id,
  ]

  username = jsondecode(data.aws_secretsmanager_secret_version.database_user.secret_string).username
  password = jsondecode(data.aws_secretsmanager_secret_version.database_password.secret_string).password

  tags = {
    AWS_Backup = "4hr7_w90",
  }

  lifecycle {
    ignore_changes = [
      username,
      password,
      engine_version
    ]
  }
}

/* DB - Route53 */
resource "aws_route53_record" "rds" {
  count   = var.app == "bcda" || var.app == "dpc" ? 1 : 0
  zone_id = var.app == "dpc" ? data.aws_route53_zone.local_zone[0].zone_id : data.aws_route53_zone.local_zone[0].zone_id
  name    = var.app == "dpc" ? "db.${aws_route53_zone.local_zone[0].name}" : "rds.${data.aws_route53_zone.local_zone[0].name}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.api.address]
}

resource "aws_route53_zone" "local_zone" {
  count = var.app == "dpc" ? 1 : 0

  name = "${var.app}-${var.env}.local"

  vpc {
    vpc_id = module.platform.vpc_id
  }
}

data "aws_route53_zone" "local_zone" {
  count        = var.app == "bcda" ? 1 : 0
  name         = "${var.app}-${var.env}.local"
  private_zone = true
}
