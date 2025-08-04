output "alb_dns_name_task11_dh" {
  value = aws_lb.strapi_alb_dh.dns_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs_strapi.name
}

output "codedeploy_app_name_dh" {
  value = aws_codedeploy_app.strapi_dh.name
}
