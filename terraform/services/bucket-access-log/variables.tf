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

variable "s3_logs_path" {
  description = "Prefix for S3 access logs."
  type        = string
  default = "s3"

  validation {
    condition     = substr(var.s3_logs_path, 0, 1) != "/" && substr(var.s3_logs_path, -1, 1) != "/" && length(var.s3_logs_path) > 0
    error_message = "Parameter `s3_logs_path` cannot start and end with \"/\", as well as cannot be empty."
  }
}
