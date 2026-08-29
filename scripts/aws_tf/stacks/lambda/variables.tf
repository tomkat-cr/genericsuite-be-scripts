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

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name with stage (lowercase)"
  type        = string
}

variable "chatbot_attachments_bucket_name" {
  description = "S3 bucket the function can read/write"
  type        = string
}

variable "package_type" {
  description = "Image or Zip"
  type        = string
  default     = "Image"
}

variable "ecr_image_tag" {
  description = "ECR image tag to deploy (Image type)"
  type        = string
  default     = "latest"
}

variable "zip_path" {
  description = "deployment.zip path (Zip type)"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda handler (Zip type)"
  type        = string
  default     = "main.handler"
}

variable "environment_variables" {
  description = "Lambda environment variables"
  type        = map(string)
  default     = {}
}

variable "api_domain_name" {
  description = "Custom API domain (e.g. app-qa.example.com); empty disables it"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the custom domain"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the custom domain record"
  type        = string
  default     = ""
}
