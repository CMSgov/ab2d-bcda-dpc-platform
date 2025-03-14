locals {
  db_name = {
    ab2d = {
      dev  = "ab2d-dev"
      test = "ab2d-east-impl"
      prod = "ab2d-east-prod"
      sbx  = "ab2d-sbx-sandbox"
    }[var.env]
    bcda = {
      dev  = "bcda-dev-rds"
      test = "bcda-test-rds"
      prod = "bcda-prod-rds-20190201"
      sbx  = "bcda-opensbx-rds-20190311"
    }[var.env]

    dpc = "${var.app}-${var.env}"
  }[var.app]

  sg_name = {
    ab2d = "${local.db_name}-database-sg"
    bcda = {
      dev  = "bcda-dev-rds"
      test = "bcda-test-rds"
      prod = "bcda-prod-rds"
      sbx  = "bcda-opensbx-rds"
    }[var.env]
    dpc = "${var.app}-${var.env}"
  }[var.app]

  instance_class = {
    ab2d = "db.m6i.2xlarge"
    bcda = var.env == "sbx" ? "db.m6i.xlarge" : "db.m6i.large"
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
  quicksight_cidr_blocks  = var.app != "ab2d" && length(data.aws_ssm_parameter.quicksight_cidr_blocks) > 0 ? jsondecode(data.aws_ssm_parameter.quicksight_cidr_blocks[0].value) : []

}

## Begin module/main.tf

# Create database security group
resource "aws_security_group" "sg_database" {
  name        = local.sg_name
  description = var.app == "ab2d" ? "${local.db_name} database security group" : "App ELB security group"
  vpc_id      = data.aws_vpc.target_vpc.id
  tags = merge(
    data.aws_default_tags.data_tags.tags,
    tomap({ "Name" = local.sg_name })
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
  description                  = "Jenkins Agent Access"
  from_port                    = "5432"
  to_port                      = "5432"
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.jenkins_security_group_id
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
  count             = var.app == "ab2d" ? 1 : 0
  description       = "Management VPC Access"
  from_port         = "5432"
  to_port           = "5432"
  ip_protocol       = "tcp"
  cidr_ipv4         = var.mgmt_vpc_cidr
  security_group_id = aws_security_group.sg_database.id
}

resource "aws_vpc_security_group_ingress_rule" "additional_ingress" {
  for_each                     = var.app == "bcda" ? toset(local.additional_ingress_sgs) : toset([])
  description                  = "Allow additional ingress to RDS on port 5432"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.sg_database.id
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "runner_access" {
  count                        = var.app != "ab2d" ? 1 : 0
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
  var.app == "bcda" && var.env == "sbx" ? "${var.app}-open${var.env}-rds-subnets" : "${var.app}-${var.env}-rds-subnets")

  subnet_ids = data.aws_subnets.db.ids

  tags = {
    Name = var.app == "ab2d" ? "${local.db_name}-rds-subnet-group" : "RDS subnet group"
  }
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
  deletion_protection = var.app == "ab2d" || var.app == "bcda" && (var.env == "prod" || var.env == "sbx") ? true : false
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]
  skip_final_snapshot = true

  db_subnet_group_name    = aws_db_subnet_group.subnet_group.name
  parameter_group_name    = var.app == "ab2d" ? aws_db_parameter_group.v16_parameter_group[0].name : null
  backup_retention_period = local.backup_retention_period
  iops                    = var.app == "bcda" ? "1000" : local.db_name == "ab2d-east-prod" ? "20000" : "5000"
  apply_immediately       = true
  max_allocated_storage   = var.app == "bcda" ? "1000" : null
  copy_tags_to_snapshot   = var.app == "bcda" ? true : false
  kms_key_id              = var.app == "ab2d" && length(data.aws_kms_alias.main_kms) > 0 ? data.aws_kms_alias.main_kms[0].target_key_arn : null
  multi_az                = var.env == "prod" || var.app == "bcda" ? true : false
  vpc_security_group_ids  = var.app == "bcda" ? concat([aws_security_group.sg_database.id], local.gdit_security_group_ids) : [aws_security_group.sg_database.id]
  username                = var.app == "ab2d" ? data.aws_secretsmanager_secret_version.database_user.secret_string : var.app == "bcda" ? jsondecode(data.aws_secretsmanager_secret_version.database_user.secret_string)["username"] : null
  password                = var.app == "ab2d" ? data.aws_secretsmanager_secret_version.database_password[0].secret_string : null
  # I'd really love to swap the password parameter here to manage_master_user_password since it's already in secrets store 

  tags = merge(
    data.aws_default_tags.data_tags.tags,
    tomap({ "Name" = var.app == "ab2d" ? "${local.db_name}-rds" : (
      var.app == "bcda" && var.env == "sbx" ? "${var.app}-open${var.env}-rds" : local.db_name),
      "role" = "db",
      "cpm backup" = var.app == "ab2d" ? "Monthly" : (
        var.app == "bcda" && var.env == "sbx" ? "4HR Daily Weekly Monthly" : "Daily Weekly Monthly"
      ) # Daily Weekly Monthly for bcda
    })
  )

  lifecycle {
    ignore_changes = [
      username,
      password
    ]
  }
}

/* DB - Route53 */
resource "aws_route53_record" "rds" {
  count   = var.app == "bcda" ? 1 : 0
  zone_id = aws_route53_zone.local_zone[0].zone_id
  name    = "rds.${aws_route53_zone.local_zone[0].name}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.api.address]
}

resource "aws_route53_zone" "local_zone" {
  count = var.app == "bcda" ? 1 : 0
  name  = var.app == "bcda" && var.env == "sbx" ? "bcda-open${var.env}.local" : "bcda-${var.env}.local"

  vpc {
    vpc_id = data.aws_vpc.target_vpc.id
  }
}
