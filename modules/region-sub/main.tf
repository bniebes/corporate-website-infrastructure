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

resource "aws_ecr_repository" "ecr" {
  name                 = "ecr_sub"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = false
}
