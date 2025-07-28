
# Get Default VPC
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

# Get individual subnet metadata (for AZ info)
data "aws_subnet" "each" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Select one subnet per AZ
locals {
  az_to_subnets = tomap({
    for subnet_id, subnet in data.aws_subnet.each :
    subnet.availability_zone => subnet_id...
  })

  unique_subnets = flatten([
    for az, subnets in local.az_to_subnets : subnets[0]
  ])
}

# Security Group
resource "aws_security_group" "strapi_dh_sg" {
  name        = "strapi-dh-sg"
  description = "Allow HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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
resource "aws_ecs_cluster" "strapi_dh_cluster" {
  name = "strapi-dh-cluster"
}

# ALB
resource "aws_lb" "strapi_dh_alb" {
  name               = "strapi-dh-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.strapi_dh_sg.id]
  subnets            = local.unique_subnets
}

# Target Group
resource "aws_lb_target_group" "strapi_dh_tg" {
  name        = "strapi-dh-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

# Listener
resource "aws_lb_listener" "strapi_dh_listener" {
  load_balancer_arn = aws_lb.strapi_dh_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_dh_tg.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "strapi_dh_task" {
  family                   = "strapi-dh-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = "${var.ecr_repo_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 1337
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "strapi_dh_service" {
  name            = "strapi-dh-service"
  cluster         = aws_ecs_cluster.strapi_dh_cluster.id
  task_definition = aws_ecs_task_definition.strapi_dh_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = local.unique_subnets
    security_groups  = [aws_security_group.strapi_dh_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.strapi_dh_tg.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.strapi_dh_listener]
}
