variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "app_name" {
  description = "Application name (lowercase)"
  type        = string
}

variable "stage" {
  description = "Deployment stage (dev, qa, staging, demo, prod)"
  type        = string
}

variable "enable_public_read" {
  description = "Allow public s3:GetObject (legacy parity; keep false)"
  type        = bool
  default     = false
}

variable "lambda_execution_role_arn" {
  description = "Lambda/EC2 execution role ARN granted read/write; empty to skip"
  type        = string
  default     = ""
}
