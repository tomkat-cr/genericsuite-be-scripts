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

variable "app_domain_name" {
  description = "Root application domain"
  type        = string
}

variable "lambda_function_name" {
  description = "Base resource name with stage (AWS_LAMBDA_FUNCTION_NAME-STAGE, lowercase)"
  type        = string
}

variable "chatbot_attachments_bucket_name" {
  description = "App S3 bucket"
  type        = string
}

variable "kms_key_alias" {
  description = "KMS key alias"
  type        = string
  default     = "genericsuite-key"
}

variable "ecr_image_tag" {
  description = "ECR image tag to deploy (ECR_DOCKER_IMAGE_TAG)"
  type        = string
  default     = "latest"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH; empty disables SSH ingress"
  type        = string
  default     = ""
}

variable "tf_state_bucket" {
  description = "TF state bucket (to read the domain stack outputs)"
  type        = string
}
