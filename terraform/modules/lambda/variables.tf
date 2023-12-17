variable "function_name" {
  description = "Name of the lambda function"
  type = string
}

variable "function_description" {
  description = "Description of the lambda function"
  type = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "vpc_id" {
  description = "ID for the AWS VPC"
  type        = string
}

variable "lambda_role_managed_policy_arns" {
  description = "Attach AWS or customer-managed IAM policies (by ARN) to the lambda IAM role"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Lambda function"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the Lambda function"
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Map of environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "create_function_zip" {
  description = "Create the function zip file, necessary for initialization (defaults to true)"
  type        = bool
  default     = true
}
