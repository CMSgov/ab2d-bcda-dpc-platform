locals {
  db_name = {
    ab2d = {
      dev  = "ab2d-dev"
      test = "ab2d-east-impl"
      prod = "ab2d-east-prod"
      sbx  = "ab2d-sbx-sandbox"
    }[var.env]
  }[var.app]
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
  description                  = "Jenkins Agent Access"
  from_port                    = "5432"
  to_port                      = "5432"
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_groups.agent_security_group_id.id
  security_group_id            = aws_security_group.sg_database.id
}

resource "aws_vpc_security_group_ingress_rule" "db_access_from_controller" {
  description                  = "Controller Access"
  from_port                    = "5432"
  to_port                      = "5432"
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_groups.controller_security_group_id.id
  security_group_id            = aws_security_group.sg_database.id
}

# Create database subnet group

resource "aws_db_subnet_group" "subnet_group" {
  name       = "${local.db_name}-rds-subnet-group"
  subnet_ids = [data.aws_subnet.private_subnet_a.id, data.aws_subnet.private_subnet_b.id]
}

# Create database parameter group

resource "aws_db_parameter_group" "parameter_group" {
  name   = "${local.db_name}-rds-parameter-group-v15"
  family = "postgres15"

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
    value        = local.db_name
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "statement_timeout"
    value        = "1200000"
    apply_method = "immediate"
  }
}

# Create database instance

resource "aws_db_instance" "api" {
  allocated_storage   = 500
  engine              = "postgres"
  engine_version      = 15.5
  instance_class      = "db.m6i.2xlarge"
  identifier          = local.db_name
  storage_encrypted   = true
  deletion_protection = true
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]
  skip_final_snapshot = true

  db_subnet_group_name    = aws_db_subnet_group.subnet_group.name
  parameter_group_name    = aws_db_parameter_group.parameter_group.name
  backup_retention_period = 7
  iops                    = local.db_name == "ab2d-east-prod" ? "20000" : "5000"
  apply_immediately       = true
  kms_key_id              = data.aws_kms_alias.main_kms.target_key_arn
  multi_az                = local.db_name == "ab2d-east-prod" ? true : false
  vpc_security_group_ids  = [aws_security_group.sg_database.id]
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
  lifecycle {
    ignore_changes = [
      engine_version,
      parameter_group_name
    ]
  }
}
