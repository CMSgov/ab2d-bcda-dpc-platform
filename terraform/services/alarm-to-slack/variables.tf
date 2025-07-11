variable "app" {
  description = "The application name (dpc)"
  type        = string
  validation {
    condition     = contains(["dpc"], var.app)
    error_message = "Valid value for app is dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}
