output "encrypted_secret_arn" {
  description = "ARN of the encrypted secrets set"
  value       = aws_secretsmanager_secret.encrypted.arn
}

output "envs_secret_arn" {
  description = "ARN of the plain envvars set"
  value       = aws_secretsmanager_secret.envs.arn
}
