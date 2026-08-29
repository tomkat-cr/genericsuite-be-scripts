output "encrypted_secret_arn" {
  description = "ARN of the encrypted secrets set"
  value       = module.secrets.encrypted_secret_arn
}

output "envs_secret_arn" {
  description = "ARN of the plain envvars set"
  value       = module.secrets.envs_secret_arn
}
