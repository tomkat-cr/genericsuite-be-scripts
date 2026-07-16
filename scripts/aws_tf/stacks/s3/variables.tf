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

variable "chatbot_attachments_bucket_name" {
  description = "Chatbot attachments bucket name (stage-resolved by wrapper)"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "Execution role ARN granted access to the bucket; empty to skip"
  type        = string
  default     = ""
}

variable "enable_public_read" {
  description = "Allow public s3:GetObject on the bucket"
  type        = bool
  default     = false
}
