variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "sandbox", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, prod, or mgmt."
  }
}
