# resource "aws_ecr_repository" "strapi" {
#   name                 = "strapi-app-ecr-dhan"
#   image_tag_mutability = "MUTABLE"
# }

# resource "aws_ecr_lifecycle_policy" "strapi_policy" {
#   repository = aws_ecr_repository.strapi.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1,
#         description  = "Keep last 10 images",
#         selection    = {
#           tagStatus     = "any",
#           countType     = "imageCountMoreThan",
#           countNumber   = 10
#         },
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }
