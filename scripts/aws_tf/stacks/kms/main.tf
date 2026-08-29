module "kms_key" {
  source = "../../modules/kms-key"

  alias    = var.kms_key_alias
  app_name = var.app_name
  stage    = var.stage
}
