source "amazon-ebs" "github-actions-runner" {
  ami_name                                  = "github-actions-runner-${formatdate("YYYYMMDDhhmm", timestamp())}"
  instance_type                             = var.instance_type
  region                                    = var.region
  vpc_id                                    = var.vpc_id
  subnet_id                                 = var.subnet_id
  associate_public_ip_address               = var.associate_public_ip_address
  temporary_security_group_source_public_ip = var.temporary_security_group_source_public_ip
  iam_instance_profile                      = "bcda-mgmt-github-actions"

  source_ami_filter {
    filters = {
      name = "al2023-legacy-gi-*"
    }
    owners = ["${var.ami_account}"]
    most_recent = true
  }

  security_group_filter {
    filters = {
      "tag:Name": "bcda-managed-vpn-private"
    }
  }

  communicator = "ssh"
  ssh_username = "ec2-user"
  ssh_timeout = "1h"
  ssh_pty = true

  # enforces IMDSv2 support on the running instance being provisioned by Packer
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 2
  }
  # enforces IMDSv2 support on the resulting AMI
  imds_support = "v2.0"

  tags = {
    Name = "github-actions-runner-ami",
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }
}
