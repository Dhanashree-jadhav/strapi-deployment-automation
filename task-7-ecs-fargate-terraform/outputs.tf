output "alb_dns_name" {
  value = aws_lb.strapi_alb.dns_name
}

#  Optional Output for Log Group
output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs_strapi.name
}