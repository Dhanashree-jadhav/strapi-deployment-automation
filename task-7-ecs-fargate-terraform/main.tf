provider "aws" {
  region = "us-east-2"
}

# --- Task 9 ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  unique_az_subnets = slice(data.aws_subnets.default.ids, 0, 2)
}

resource "aws_security_group" "strapi_sg" {
  name        = "strapi-task9-sg"
  description = "Allow HTTP/1337"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "strapi_task9" {
  name = "strapi-task9-cluster"
}

resource "aws_lb" "strapi_task9_alb" {
  name               = "strapi-task9-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.strapi_sg.id]
  subnets            = local.unique_az_subnets
}

resource "aws_lb_target_group" "strapi_task9_tg" {
  name        = "strapi-task9-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "strapi_task9_http" {
  load_balancer_arn = aws_lb.strapi_task9_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_task9_tg.arn
  }
}

resource "aws_cloudwatch_log_group" "ecs_strapi" {
  name              = "/ecs/strapi"
  retention_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task7"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  execution_role_arn       = "arn:aws:iam::607700977843:role/ecs-task-execution-role"
  task_role_arn            = "arn:aws:iam::607700977843:role/ecs-task-execution-role"

  container_definitions = jsonencode([{
    name      = "strapi"
    image     = var.image_url
    essential = true
    portMappings = [{
      containerPort = 1337
      protocol      = "tcp"
    }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_strapi.name,
        awslogs-region        = "us-east-2",
        awslogs-stream-prefix = "ecs/strapi"
      }
    },

     # 👇 Add this line inside the container_definitions block
    environment = [{
      name  = "REDEPLOY"
      value = "v1" # Change to a new value (e.g., v2, v3...) whenever you want to trigger a new deployment
    }]
    
  }])
}

resource "aws_ecs_service" "strapi_task9" {
  name            = "strapi-task9-service"
  cluster         = aws_ecs_cluster.strapi_task9.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets         = local.unique_az_subnets
    security_groups = [aws_security_group.strapi_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.strapi_task9_tg.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.strapi_task9_http]
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "strapi-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This alarm triggers if CPU > 75% for 2 minutes."
  dimensions = {
    ClusterName = aws_ecs_cluster.strapi_task9.name
    ServiceName = aws_ecs_service.strapi_task9.name
  }
}

# ======================= Task 11 (Blue/Green) -dh ==========================

resource "aws_security_group" "strapi_alb_sg_dh" {
  name        = "strapi-task11-alb-sg-dh"
  description = "Allow HTTP/HTTPS for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "strapi_alb_dh" {
  name               = "strapi-task11-alb-dh"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.strapi_alb_sg_dh.id]
  subnets            = local.unique_az_subnets
}

resource "aws_lb_target_group" "strapi_blue_tg_dh" {
  name        = "strapi-blue-tg-dh"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_target_group" "strapi_green_tg_dh" {
  name        = "strapi-green-tg-dh"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "strapi_listener_dh" {
  load_balancer_arn = aws_lb.strapi_alb_dh.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_blue_tg_dh.arn
  }
}

resource "aws_ecs_cluster" "strapi_cluster_dh" {
  name = "strapi-task11-cluster-dh"
}

resource "aws_ecs_service" "strapi_service_dh" {
  name            = "strapi-task11-service-dh"
  cluster         = aws_ecs_cluster.strapi_cluster_dh.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets         = local.unique_az_subnets
    security_groups = [aws_security_group.strapi_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.strapi_blue_tg_dh.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.strapi_listener_dh]
}
