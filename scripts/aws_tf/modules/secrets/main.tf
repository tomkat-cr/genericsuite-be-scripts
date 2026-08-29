data "aws_kms_alias" "this" {
  name = "alias/${var.kms_key_alias}"
}

locals {
  stage_uppercase = upper(var.stage)
}

resource "aws_secretsmanager_secret" "encrypted" {
  name        = "${var.app_name}-${var.stage}-secrets"
  description = "Encrypted-Secrets-for-${var.app_name}-${local.stage_uppercase}"
  kms_key_id  = data.aws_kms_alias.this.target_key_arn
}

resource "aws_secretsmanager_secret_version" "encrypted" {
  secret_id     = aws_secretsmanager_secret.encrypted.id
  secret_string = jsonencode(var.secrets_map)
}

resource "aws_secretsmanager_secret" "envs" {
  name        = "${var.app_name}-${var.stage}-envs"
  description = "Environment-variables-for-${var.app_name}-${local.stage_uppercase}"
}

resource "aws_secretsmanager_secret_version" "envs" {
  secret_id     = aws_secretsmanager_secret.envs.id
  secret_string = jsonencode(var.envs_map)
}
