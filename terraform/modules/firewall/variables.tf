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

variable "scope" {
  description = "Firewall scope"
  default     = null
}

variable "name" {
  description = "Web ACL name"
}

variable "aws_lb_arn" {
  description = "ARN of the LoadBalancer to attach the WAF to."
}

variable "rate_based_rule" {
  type = object({
    name          = string
    priority      = number
    limit         = number
    action        = string
    response_code = optional(number, 403)
  })
  description = "A rule for the number of requests to accept over the course of 5 minutes."
  default     = null
}

variable "ip_sets_rule" {
  type = list(object({
    name          = string
    priority      = number
    ip_set_arn    = string
    action        = string
    response_code = optional(number, 403)
  }))
  description = "A rule to detect web requests coming from particular IP addresses or address ranges."
  default     = []
}