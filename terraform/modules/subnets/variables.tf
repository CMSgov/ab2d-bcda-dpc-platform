variable "vpc_id" {
  description = "ID for the AWS VPC"
  type        = string
}

variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "layer" {
  description = "The subnet layer for bcda or dpc (app, data, dmz, management, transitive, web)"
  type        = string
  validation {
    condition     = contains(["app", "data", "dmz", "management", "transitive", "web"], var.layer)
    error_message = "Valid value for layer is app, data, dmz, management, transitive, or web."
  }
}

variable "use" {
  description = "The use, private or public, for the subnet (ab2d only)"
  type        = string
  default     = "private"
  validation {
    condition     = contains(["private", "public"], var.use)
    error_message = "Valid value for use is private or public."
  }
}
