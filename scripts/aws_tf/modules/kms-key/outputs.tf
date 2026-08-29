output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.this.key_id
}

output "alias_arn" {
  description = "KMS alias ARN"
  value       = aws_kms_alias.this.arn
}

output "asg_role_arn" {
  description = "ASG role ARN"
  value       = aws_iam_role.asg.arn
}
