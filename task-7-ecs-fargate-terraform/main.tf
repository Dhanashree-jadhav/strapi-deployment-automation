provider "aws" {
  region = "us-east-2"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Pick only 2 unique subnets (one per AZ)
locals {
  unique_az_subnets = slice(data.aws_subnets.default.ids, 0, 2)
}

# Security Group for ECS task
resource "aws_security_group" "strapi_sg" {
  name        = "strapi-task7-sg"
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

# ECS Cluster
resource "aws_ecs_cluster" "strapi" {
  name = "strapi-task7-cluster"
}

# Application Load Balancer
resource "aws_lb" "strapi_alb" {
  name               = "strapi-task7-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.strapi_sg.id]
  subnets            = local.unique_az_subnets
}

# Target Group
resource "aws_lb_target_group" "strapi_tg" {
  name        = "strapi-task7-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.strapi_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_tg.arn
  }
}

# 2. Update ECS Task Definition with awslogs config
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
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "strapi" {
  name            = "strapi-task7-service"
  cluster         = aws_ecs_cluster.strapi.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = local.unique_az_subnets
    security_groups = [aws_security_group.strapi_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.strapi_tg.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.http]
}


# 1. Add CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_strapi" {
  name              = "/ecs/strapi"
  retention_in_days = 7
  skip_destroy      = false

  lifecycle {
    prevent_destroy = true
  }
}

# 3. Optional: CloudWatch Alarm for CPU Utilization
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
    ClusterName = aws_ecs_cluster.strapi.name
    ServiceName = aws_ecs_service.strapi.name
  }
}