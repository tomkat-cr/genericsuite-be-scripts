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

variable "ecr_repository_name" {
  description = "ECR repository name holding the app image"
  type        = string
}

variable "ecr_image_uri" {
  description = "Full ECR image URI (without tag)"
  type        = string
}

variable "ecr_image_tag" {
  description = "ECR image tag to run"
  type        = string
  default     = "latest"
}

variable "domain_name" {
  description = "FQDN for the ALB (e.g. api-qa-2.example.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN for the HTTPS listener"
  type        = string
}

variable "s3_bucket_name" {
  description = "App S3 bucket the instance can read/write"
  type        = string
}

variable "kms_key_alias" {
  description = "KMS key alias"
  type        = string
  default     = "genericsuite-key"
}

variable "asm_secrets_arn" {
  description = "Secrets Manager encrypted secrets ARN"
  type        = string
}

variable "asm_envs_arn" {
  description = "Secrets Manager envvars ARN"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "create_key_pair" {
  description = "Create the SSH key pair and write the .pem locally"
  type        = bool
  default     = true
}

variable "ssh_keys_directory" {
  description = "Local directory for the generated .pem file"
  type        = string
  default     = "~/.ssh"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH; empty disables SSH ingress (use SSM)"
  type        = string
  default     = ""
}

variable "asg_min_size" {
  description = "ASG minimum size"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG maximum size"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 1
}
