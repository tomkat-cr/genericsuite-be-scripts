output "lambda_repository_url" {
  description = "ECR repository URL for Lambda images"
  value       = module.lambda_repository.repository_url
}

output "ec2_repository_url" {
  description = "ECR repository URL for EC2 images"
  value       = var.create_ec2_repository ? module.ec2_repository[0].repository_url : ""
}
