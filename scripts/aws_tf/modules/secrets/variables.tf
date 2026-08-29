variable "app_name" {
  description = "Application name (lowercase)"
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}

variable "kms_key_alias" {
  description = "KMS key alias used to encrypt the secrets set"
  type        = string
  default     = "genericsuite-key"
}

variable "secrets_map" {
  description = "Encrypted secrets key/value map"
  type        = map(string)
  sensitive   = true
}

variable "envs_map" {
  description = "Plain environment variables key/value map"
  type        = map(string)
}
