variable "repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "images_to_keep" {
  description = "How many most-recent images to keep (parity with clean_ecr_images.sh)"
  type        = number
  default     = 2
}
