variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, or prod."
  }
}

variable "name" {
  description = "Name of the lambda function"
  type        = string
}

variable "description" {
  description = "Description of the lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "function_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda function timeout"
  type        = number
  default     = 900
}

variable "memory_size" {
  description = "Lambda function memory size"
  type        = number
  default     = null
}

variable "function_role_inline_policies" {
  description = "Inline policies (in JSON) for the function IAM role"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Map of environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "create_function_zip" {
  description = "Create the function zip file, necessary for initialization (defaults to true)"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "Cron or rate expression for a scheduled function"
  type        = string
  default     = ""
}
