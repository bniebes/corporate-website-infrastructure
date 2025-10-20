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

data "aws_region" "current" {}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_main" {
  name                 = "ecr-main-${data.aws_region.current.region}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = var.ecr_force_delete
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

# AWS IAM #############################################################################################################

resource "aws_iam_role" "role_apprunner_ecr" {
  name = "role-apprunner-ecr-${data.aws_region.current.region}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "build.apprunner.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "policy_apprunner_ecr" {
  role       = aws_iam_role.role_apprunner_ecr.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

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

# AWS App Runner ######################################################################################################

resource "aws_apprunner_auto_scaling_configuration_version" "corporate_website_auto_scaling" {
  count                           = var.initial_deployment ? 0 : 1
  auto_scaling_configuration_name = "corporate-website-auto-scaling-${data.aws_region.current.region}"

  max_concurrency = var.auto_scaling_max_concurrency
  max_size        = var.auto_scaling_max_size
  min_size        = var.auto_scaling_min_size
}

resource "aws_apprunner_service" "corporate_website" {
  count        = var.initial_deployment ? 0 : 1
  service_name = "corporate-website-${data.aws_region.current.region}"

  source_configuration {

    # Only add authentication configuration if not initial deployment
    authentication_configuration {
      access_role_arn = aws_iam_role.role_apprunner_ecr.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.ecr_main.repository_url}/${var.image_name}:${var.image_tag}"
      image_repository_type = "ECR"
      image_configuration {
        port = "30123"
      }
    }

    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = var.instance_cpu
    memory = var.instance_memory
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.corporate_website_auto_scaling[count.index].arn

  network_configuration {

    ingress_configuration {
      is_publicly_accessible = true
    }
  }

  tags = {
    Name     = "corporate-website-apprunner-service"
    Image    = "corporate-website"
    ImageTag = "prod"
  }
}

# AWS Route53 #########################################################################################################

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "apprunner_domain" {
  count          = var.initial_deployment ? 0 : 1
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "CNAME"
  ttl            = 60
  records        = [aws_apprunner_service.corporate_website[count.index].service_url]
  set_identifier = data.aws_region.current.region

  latency_routing_policy {
    region = data.aws_region.current.region
  }
}
