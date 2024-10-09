source "amazon-ebs" "github-actions-runner" {
  ami_name           = "github-actions-runner-${formatdate("YYYYMMDDhhmm", timestamp())}"
  instance_type      = var.instance_type
  region             = var.region
  vpc_id             = var.vpc_id
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids

  iam_instance_profile = "bcda-mgmt-github-actions"

  source_ami_filter {
    filters = {
      name = "al2023-legacy-gi-*"
    }
    owners      = ["${var.ami_account}"]
    most_recent = true
  }

  communicator  = "ssh"
  ssh_interface = "session_manager"
  ssh_username  = "ec2-user"
  ssh_timeout   = "10m"
  ssh_pty       = true

  # Enforces IMDSv2 support on the running instance being provisioned by Packer
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Enforces IMDSv2 support on the resulting AMI
  imds_support = "v2.0"

  tags = {
    Name          = "github-actions-runner-ami",
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }
}
