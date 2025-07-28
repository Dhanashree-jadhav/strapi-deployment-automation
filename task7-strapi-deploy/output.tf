output "alb_url" {
  value       = aws_lb.strapi_dh_alb.dns_name
  description = "Public URL for the Strapi app"
}
