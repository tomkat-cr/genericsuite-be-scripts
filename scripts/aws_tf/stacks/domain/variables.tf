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

variable "app_domain_name" {
  description = "Root application domain (APP_DOMAIN_NAME in .env)"
  type        = string
}

variable "api_domain_name" {
  description = "API FQDN override; empty computes api-{stage}-2.{app_domain_name}"
  type        = string
  default     = ""
}
