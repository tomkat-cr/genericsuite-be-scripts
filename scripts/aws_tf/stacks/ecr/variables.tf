variable "app_name" {
  description = "Application name (lowercase)"
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_function_name" {
  description = "Base resource name with stage (AWS_LAMBDA_FUNCTION_NAME-STAGE, lowercase)"
  type        = string
}

variable "images_to_keep" {
  description = "How many most-recent images to keep"
  type        = number
  default     = 2
}

variable "create_ec2_repository" {
  description = "Also create the -ec2 repository used by the EC2/ALB deployment"
  type        = bool
  default     = true
}
