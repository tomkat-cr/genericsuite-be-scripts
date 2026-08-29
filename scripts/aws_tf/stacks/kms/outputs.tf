output "key_arn" {
  description = "KMS key ARN"
  value       = module.kms_key.key_arn
}

output "alias_arn" {
  description = "KMS alias ARN"
  value       = module.kms_key.alias_arn
}
