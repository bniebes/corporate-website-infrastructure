# region-main #########################################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_main" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = var.ecr_force_delete
}

resource "aws_ecr_replication_configuration" "ecr_main" {
  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = var.sub_regions
        content {
          region      = destination.key
          registry_id = data.aws_caller_identity.current.account_id
        }
      }
    }
  }
}

# AWS IAM #############################################################################################################

resource "aws_iam_user" "cicd_user" {
  name = "cicd-user-ecr-push"
  path = "/service-accounts/"

  tags = {
    Purpose   = "CI/CD"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_access_key" "cicd_user_key" {
  user = aws_iam_user.cicd_user.name
}

resource "aws_iam_policy" "policy_push_ecr" {
  name        = "policy-push-ecr"
  description = "Policy for pushing images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cicd_user_ecr_push" {
  user       = aws_iam_user.cicd_user.name
  policy_arn = aws_iam_policy.policy_push_ecr.arn
}

# AWS Route53 #########################################################################################################

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# AWS App Runner ######################################################################################################

module "apprunner" {
  count  = var.initial_deployment ? 0 : 1
  source = "../apprunner"

  domain_name                  = var.domain_name
  zone_id                      = aws_route53_zone.main.zone_id
  repository_url               = aws_ecr_repository.ecr_main.repository_url
  image_tag                    = var.image_tag
  instance_cpu                 = var.instance_cpu
  instance_memory              = var.instance_memory
  auto_scaling_max_concurrency = var.auto_scaling_max_concurrency
  auto_scaling_max_size        = var.auto_scaling_max_size
  auto_scaling_min_size        = var.auto_scaling_min_size
}
