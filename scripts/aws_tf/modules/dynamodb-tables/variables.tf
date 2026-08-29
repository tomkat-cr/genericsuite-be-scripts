variable "app_name" {
  description = "Application name (lowercase)"
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}

variable "tables" {
  description = "DynamoDB table definitions from the GenericSuite JSON config"
  type = list(object({
    name      = string
    hash_key  = string
    range_key = optional(string)
  }))
}
