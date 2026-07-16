output "endpoint_url" {
  description = "Default API Gateway invoke URL"
  value       = module.lambda_api.endpoint_url
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda_api.function_arn
}

output "custom_domain_url" {
  description = "Custom domain URL"
  value       = module.lambda_api.custom_domain_url
}
