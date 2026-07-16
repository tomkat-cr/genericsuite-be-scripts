locals {
  api_domain_name = var.api_domain_name != "" ? var.api_domain_name : "api-${var.stage}-2.${var.app_domain_name}"
}

module "app_domain" {
  source = "../../modules/app-domain"

  domain_name      = local.api_domain_name
  hosted_zone_name = var.app_domain_name
  app_name         = var.app_name
  stage            = var.stage
}
