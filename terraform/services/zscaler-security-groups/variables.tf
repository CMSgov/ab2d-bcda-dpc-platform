variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, mgmt, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "mgmt", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, mgmt, sbx, or prod."
  }
}


variable "private_cidrs" {
  type        = list(string)
  description = "private ip list"
}
variable "public_cidrs" {
  type        = list(string)
  description = "public ip list"
}
