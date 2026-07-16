output "bucket_name" {
  description = "Chatbot attachments bucket name"
  value       = module.chatbot_attachments_bucket.bucket_name
}

output "bucket_arn" {
  description = "Chatbot attachments bucket ARN"
  value       = module.chatbot_attachments_bucket.bucket_arn
}
