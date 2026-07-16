output "endpoint_url" {
  description = "Default API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage}"
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "rest_api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}

output "custom_domain_url" {
  description = "Custom domain URL (empty when no domain configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : ""
}
