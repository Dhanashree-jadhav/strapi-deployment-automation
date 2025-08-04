resource "aws_iam_role" "codedeploy_role_dh" {
  name = "strapi-codedeploy-role-dh"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_attach_dh" {
  role       = aws_iam_role.codedeploy_role_dh.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_codedeploy_app" "strapi_dh" {
  name             = "strapi-codedeploy-app-dh"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "strapi_dh" {
  app_name               = aws_codedeploy_app.strapi_dh.name
  deployment_group_name  = "strapi-deployment-group-dh"
  service_role_arn       = aws_iam_role.codedeploy_role_dh.arn
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.strapi_cluster_dh.name
    service_name = aws_ecs_service.strapi_service_dh.name
  }

  load_balancer_info {
    target_group_pair_info {
      target_group {
        name = aws_lb_target_group.strapi_blue_tg_dh.name
      }

      target_group {
        name = aws_lb_target_group.strapi_green_tg_dh.name
      }

      prod_traffic_route {
        listener_arns = [aws_lb_listener.strapi_listener_dh.arn]
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }
}
