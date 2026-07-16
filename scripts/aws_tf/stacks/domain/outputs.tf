output "certificate_arn" {
  description = "Validated ACM certificate ARN"
  value       = module.app_domain.certificate_arn
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.app_domain.hosted_zone_id
}

output "domain_name" {
  description = "API FQDN"
  value       = local.api_domain_name
}
