variable "alias" {
  description = "KMS key alias (without the alias/ prefix)"
  type        = string
  default     = "genericsuite-key"
}

variable "app_name" {
  description = "Application name (lowercase)"
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}
