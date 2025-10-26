# region-main #########################################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_sub" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = var.ecr_force_delete
}

# AWS App Runner ######################################################################################################

module "apprunner" {
  count  = var.initial_deployment ? 0 : 1
  source = "../apprunner"

  domain_name                  = var.domain_name
  zone_id                      = var.zone_id
  repository_url               = aws_ecr_repository.ecr_sub.repository_url
  image_tag                    = var.image_tag
  instance_cpu                 = var.instance_cpu
  instance_memory              = var.instance_memory
  auto_scaling_max_concurrency = var.auto_scaling_max_concurrency
  auto_scaling_max_size        = var.auto_scaling_max_size
  auto_scaling_min_size        = var.auto_scaling_min_size
}
