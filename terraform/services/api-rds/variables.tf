# Restricting valid "app" values until service has been extended or BCDA and DPC

variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, or prod."
  }
}

variable "mgmt_vpc_cidr" {
  description = "CIDR for the Management VPC"
  type        = string
}

variable "name" {
  description = "If more than one RDS instance is needed, this variable should be set"
  type        = string
  default     = "db"
}

variable "snapshot" {
  description = "If specified, create a new RDS instance which is restored from this snapshot."
  type        = string
  default     = null
}
