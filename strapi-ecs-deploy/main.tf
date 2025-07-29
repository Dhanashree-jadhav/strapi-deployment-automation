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

# Security Group for ECS/ALB
resource "aws_security_group" "strapi_sg" {
  name        = "strapi-sg-dhan"
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

# ECS Cluster (safe to delete)
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-ecs-cluster-dhan"
}

# ALB
resource "aws_lb" "strapi_alb" {
  name               = "strapi-alb-dhan"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.strapi_sg.id]
  subnets            = local.unique_subnets
}

# Target Group
resource "aws_lb_target_group" "strapi_tg" {
  name        = "strapi-tg-dhan"
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
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.strapi_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_tg.arn
  }
}

resource "aws_ecr_repository" "strapi" {
  name = "strapi-app-ecr-dhan"

  lifecycle {
    prevent_destroy = true
  }
}
