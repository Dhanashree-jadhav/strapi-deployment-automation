output "ecr_repository_url" {
  value = aws_ecr_repository.strapi.repository_url
}

output "alb_url" {
  value       = aws_lb.strapi_alb.dns_name
  description = "Public ALB URL to access Strapi"
}
