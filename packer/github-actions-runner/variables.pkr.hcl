variable "region" {
  description = "The region to build the image in"
  type        = string
  default     = "us-east-1"
}

variable "ami_account" {
  description = "The target AMI account"
  type        = string
  default     = null
}

variable "s3_tarball" {
  description = "The target S3 bucket for the Github Runner Agent"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "The instance type Packer will use for the builder"
  type        = string
  default     = "t3.xlarge"
}

variable "vpc_id" {
  description = "The name of the VPC where the instance will be launched"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "If using VPC, the ID of the subnet, such as subnet-12345def, where Packer will launch the EC2 instance. This field is required if you are using an non-default VPC"
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "If using a non-default VPC, there is no public IP address assigned to the EC2 instance. If you specified a public subnet, you probably want to set this to true. Otherwise the EC2 instance won't have access to the internet"
  type        = string
  default     = null
}

variable "temporary_security_group_source_public_ip" {
  description = "When enabled, use public IP of the host (obtained from https://checkip.amazonaws.com) as CIDR block to be authorized access to the instance, when packer is creating a temporary security group. Note: If you specify `security_group_id` then this input is ignored."
  type        = bool
  default     = false
}

variable "global_tags" {
  description = "Tags to apply to everything"
  type        = map(string)
  default     = {}
}

variable "ami_tags" {
  description = "Tags to apply to the AMI"
  type        = map(string)
  default     = {}
}

variable "snapshot_tags" {
  description = "Tags to apply to the snapshot"
  type        = map(string)
  default     = {}
}

variable "custom_shell_commands" {
  description = "Additional commands to run on the EC2 instance, to customize the instance, like installing packages"
  type        = list(string)
  default     = []
}

variable "runner_version" {
  description = "The version (no v prefix) of the runner software to install https://github.com/actions/runner/releases. The latest release will be fetched from GitHub if not provided."
  default     = null
}

data "http" github_runner_release_json {
  url = "https://api.github.com/repos/actions/runner/releases/latest"
  request_headers = {
    Accept = "application/vnd.github+json"
    X-GitHub-Api-Version : "2022-11-28"
  }
}

locals {
  runner_version = coalesce(var.runner_version, trimprefix(jsondecode(data.http.github_runner_release_json.body).tag_name, "v"))
}
