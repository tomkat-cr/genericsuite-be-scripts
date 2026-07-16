variable "function_name" {
  description = "Lambda function name (e.g. myapp-backend-qa)"
  type        = string
}

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

variable "package_type" {
  description = "Lambda package type: Image or Zip"
  type        = string
  default     = "Image"
  validation {
    condition     = contains(["Image", "Zip"], var.package_type)
    error_message = "package_type must be Image or Zip."
  }
}

variable "image_uri" {
  description = "ECR image URI with tag (package_type = Image)"
  type        = string
  default     = ""
}

variable "zip_path" {
  description = "Path to deployment.zip (package_type = Zip)"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda handler (package_type = Zip)"
  type        = string
  default     = "main.handler"
}

variable "runtime" {
  description = "Python runtime (package_type = Zip)"
  type        = string
  default     = "python3.12"
}

variable "memory_size" {
  description = "Lambda memory (MB)"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout (seconds)"
  type        = number
  default     = 180
}

variable "environment_variables" {
  description = "Lambda environment variables"
  type        = map(string)
  default     = {}
}

variable "chatbot_attachments_bucket_name" {
  description = "S3 bucket the function can read/write"
  type        = string
}

variable "asm_secrets_arn" {
  description = "Secrets Manager encrypted secrets ARN pattern"
  type        = string
}

variable "asm_envs_arn" {
  description = "Secrets Manager envvars ARN pattern"
  type        = string
}

variable "domain_name" {
  description = "Custom API domain; empty disables the custom domain"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the custom domain (us-east-1 for EDGE)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 zone for the custom domain record; empty skips the record"
  type        = string
  default     = ""
}

variable "binary_media_types" {
  description = "API Gateway binary media types"
  type        = list(string)
  default = [
    "multipart/form-data", "audio/basic", "audio/ogg", "audio/mp4",
    "audio/mpeg", "audio/wav", "audio/webm", "image/png", "image/jpg",
    "image/jpeg", "image/gif", "video/ogg", "video/mpeg", "video/webm",
    "application/octet-stream", "application/x-tar", "application/zip",
  ]
}
