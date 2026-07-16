module "secrets" {
  source = "../../modules/secrets"

  app_name      = var.app_name
  stage         = var.stage
  kms_key_alias = var.kms_key_alias
  secrets_map   = var.secrets_map
  envs_map      = var.envs_map
}
