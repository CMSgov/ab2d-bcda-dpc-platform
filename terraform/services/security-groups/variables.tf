variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}

variable "env" {
  description = "The application environment (dev, test, mgmt, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "mgmt", "sbx", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, mgmt, sbx, sandbox, or prod."
  }
}
