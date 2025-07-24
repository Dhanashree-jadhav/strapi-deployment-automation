variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "docker_image" {
  type        = string
  description = "Docker image to pull"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name"
}
