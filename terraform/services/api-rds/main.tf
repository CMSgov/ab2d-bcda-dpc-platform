locals {
  db_name = {
    ab2d = {
      dev  = "ab2d-dev"
      test = "ab2d-east-impl"
      prod = "ab2d-east-prod"
      sbx  = "ab2d-sbx-sandbox"
    }[var.env]
    bcda = "${var.app}-${var.env}"
    dpc  = "${var.app}-${var.env}"
  }[var.app]

  instance_class = {
    ab2d = "db.m6i.2xlarge"
    bcda = "db.m6i.large"
  }[var.app]

  allocated_storage = {
    ab2d = 500
    bcda = 100
  }[var.app]

  backup_retention_period = {
    ab2d = 7
    bcda = 35
  }[var.app]

  additional_ingress_sgs  = var.app == "bcda" ? flatten([data.aws_security_group.app_sg[0].id, data.aws_security_group.worker_sg[0].id]) : []
  gdit_security_group_ids = var.app == "bcda" ? flatten([for sg in data.aws_security_group.gdit : sg.id]) : []
}

## Begin module/main.tf

# Create database security group
resource "aws_security_group" "sg_database" {
  name        = "${local.db_name}-database-sg"
  description = "${local.db_name} database security group"
  vpc_id      = data.aws_vpc.target_vpc.id
  tags = merge(
    data.aws_default_tags.data_tags.tags,
    tomap({ "Name" = "${local.db_name}-database-sg" })
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "egress_all" {
  security_group_id = aws_security_group.sg_database.id

  description = "Allow all egress"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_ingress_rule" "db_access_from_jenkins_agent" {
  for_each = var.app == "bcda" ? toset([data.aws_security_group.app_sg[0].id, data.aws_security_group.worker_sg[0].id, var.jenkins_security_group_id]) : var.app == "ab2d" ? toset([var.jenkins_security_group_id]) : toset([])

  description                  = "Jenkins Agent Access"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  security_group_id            = aws_security_group.sg_database.id
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
  description       = "Management VPC Access"
  from_port         = "5432"
  to_port           = "5432"
  ip_protocol       = "tcp"
  cidr_ipv4         = var.mgmt_vpc_cidr
  security_group_id = aws_security_group.sg_database.id
}

# Create database subnet group

resource "aws_db_subnet_group" "subnet_group" {
  name = var.app == "bcda" ? "${var.app}-${var.env}-rds-subnets" : "${local.db_name}-rds-subnet-group"

  subnet_ids = data.aws_subnets.db.ids

  tags = {
    Name = var.app == "bcda" ? "RDS subnet group" : "${local.db_name}-rds-subnet-group"
  }
}

# Create database parameter group

resource "aws_db_parameter_group" "v16_parameter_group" {
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
  identifier          = var.app == "bcda" ? "${var.app}-${var.env}-rds" : local.db_name
  storage_encrypted   = true
  deletion_protection = true
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]
  skip_final_snapshot = true

  db_subnet_group_name    = aws_db_subnet_group.subnet_group.name
  parameter_group_name    = aws_db_parameter_group.v16_parameter_group.name
  backup_retention_period = local.backup_retention_period
  iops                    = var.app == "bcda" ? "1000" : local.db_name == "ab2d-east-prod" ? "20000" : "5000"
  apply_immediately       = true
  kms_key_id              = var.app == "ab2d" && length(data.aws_kms_alias.main_kms) > 0 ? data.aws_kms_alias.main_kms[0].target_key_arn : null
  multi_az                = var.env == "prod" ? true : false
  vpc_security_group_ids  = var.app == "bcda" ? concat([aws_security_group.sg_database.id], local.gdit_security_group_ids) : [aws_security_group.sg_database.id]
  username                = data.aws_secretsmanager_secret_version.database_user.secret_string
  password                = data.aws_secretsmanager_secret_version.database_password.secret_string
  # I'd really love to swap the password parameter here to manage_master_user_password since it's already in secrets store 

  tags = merge(
    data.aws_default_tags.data_tags.tags,
    tomap({ "Name" = "${local.db_name}-rds",
      "role"       = "db",
      "cpm backup" = "Monthly"
    })
  )
}

/* DB - Route53 */
resource "aws_route53_record" "rds" {
  count   = var.app == "bcda" ? 1 : 0
  zone_id = aws_route53_zone.local_zone[0].zone_id
  name    = "rds"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.api.address]
}

resource "aws_route53_zone" "local_zone" {
  count = var.app == "bcda" ? 1 : 0
  name  = "bcda-${var.env}.local"

  vpc {
    vpc_id = data.aws_vpc.target_vpc.id
  }
}
