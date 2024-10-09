variable "region" {
  description = "The region to build the image in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "The instance type Packer will use for the builder"
  type        = string
  default     = "t3.large"
}

variable "ami_account" {
  description = "The target AMI account"
  type        = string
}

variable "s3_tarball" {
  description = "The target S3 bucket for the Github Runner Agent"
  type        = string
}

variable "vpc_id" {
  description = "The name of the VPC where the instance will be launched"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where Packer will launch the EC2 instance"
  type        = string
}

variable "security_group_ids" {
  description = "IDs for security groups to attach to the builder. Should be set to IDs for cmscloud-security-tools and bcda-mgmt-internet."
  type        = list(string)
}
