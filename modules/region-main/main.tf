# region-main #########################################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

variable "sub_regions" {
  type        = set(string)
  nullable    = false
  description = "Active sub regions"
}

data "aws_caller_identity" "current" {}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr" {
  name                 = "ecr_main"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = false
}

resource "aws_ecr_replication_configuration" "ecr_main" {
  for_each = var.sub_regions
  replication_configuration {
    rule {
      destination {
        region      = each.key
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}
