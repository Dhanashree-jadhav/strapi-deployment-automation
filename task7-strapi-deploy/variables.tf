variable "execution_role_arn" {
  description = "IAM role ARN for ECS task execution and task role"
  default     = "arn:aws:iam::607700977843:role/ecs-task-execution-role"
}

variable "ecr_repo_url" {
  description = "ECR repo URL"
  default     = "607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-ecr-dhan"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  default     = "latest"
}
