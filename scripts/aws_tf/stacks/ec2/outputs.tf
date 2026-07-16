output "load_balancer_dns_name" {
  description = "ALB DNS name"
  value       = module.ec2_alb.load_balancer_dns_name
}

output "app_url" {
  description = "Application URL"
  value       = module.ec2_alb.app_url
}
