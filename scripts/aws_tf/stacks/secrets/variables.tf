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

variable "kms_key_alias" {
  description = "KMS key alias"
  type        = string
  default     = "genericsuite-key"
}

variable "secrets_map" {
  description = "Encrypted secrets key/value map (built by build-tfvars.sh)"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "envs_map" {
  description = "Plain envvars key/value map (built by build-tfvars.sh)"
  type        = map(string)
  default     = {}
}
