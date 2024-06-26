variable "region" {
    description = "AWS region"
    default = "us-east-1"
}

variable "aws_lb_arn" {
    description = "ARN of the LoadBalancer to attach the WAF to"
}
