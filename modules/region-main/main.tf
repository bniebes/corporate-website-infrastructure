# region-main #########################################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

# Data #############################################################################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Variables #############################################################################################################

variable "sub_regions" {
  type        = set(string)
  nullable    = false
  description = "Active sub regions"
}

variable "ecr_force_delete" {
  type        = bool
  default     = false
  description = "AWS ECR force delete"
}

variable "domain_name" {
  type = string
  description = "Root domain name"
}

variable "instance_cpu" {
  type = string
  default = "1 vCPU"
  description = "App Runner Instance CPU"
}

variable "instance_memory" {
  type = string
  default = "0.5 GB"
  description = "App Runner Instance Memory"
}

variable "auto_scaling_max_concurrency" {
  type = number
  default = 100
  description = "App Runner Auto Scaling Max Concurrency. (Number of Concurrent requests)"
}

variable "auto_scaling_max_size" {
  type = number
  default = 10
  description = "App Runner Auto Scaling Max Size"
}

variable "auto_scaling_min_size" {
  type = number
  default = 1
  description = "App Runner Auto Scaling Min Size"
}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_main" {
  name                 = "ecr-main"
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
  name = "role-apprunner-ecr"
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
    Purpose     = "CI/CD"
    ManagedBy   = "terraform"
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

resource "time_sleep" "wait_role_create" {
  depends_on      = [aws_iam_role.role_apprunner_ecr]
  create_duration = "30s"
}

resource "aws_apprunner_service" "corporate_website" {
  service_name = "corporate-website"
  depends_on   = [time_sleep.wait_role_create]

  source_configuration {

    authentication_configuration {
      access_role_arn = aws_iam_role.role_apprunner_ecr.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.ecr_main.repository_url}/corporate-website:prod"
      image_repository_type = "ECR"
      image_configuration {
        port = "30123"
      }
    }

    auto_deployments_enabled = true
  }

  instance_configuration {
    cpu = var.instance_cpu
    memory = var.instance_memory
  }

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

resource "aws_apprunner_auto_scaling_configuration_version" "corporate_website_auto_scaling" {
  auto_scaling_configuration_name = "corporate-website-auto-scaling"

  max_concurrency = var.auto_scaling_max_concurrency
  max_size = var.auto_scaling_max_size
  min_size = var.auto_scaling_min_size
}

# AWS Route53 #########################################################################################################

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "subdomain_main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${data.aws_region.current.region}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_service.corporate_website.service_url]
}

resource "aws_route53_record" "rootdomain_main" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "CNAME"
  ttl            = 60
  records        = [aws_apprunner_service.corporate_website.service_url]
  set_identifier = data.aws_region.current.region

  latency_routing_policy {
    region = data.aws_region.current.region
  }
}

# Outputs #############################################################################################################

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone - update these at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "user_name" {
  value       = aws_iam_user.cicd_user.name
  description = "IAM username for CI/CD"
}

output "access_key_id" {
  value       = aws_iam_access_key.cicd_user_key.id
  description = "Access key ID for CI/CD user"
  sensitive   = true
}

output "secret_access_key" {
  value       = aws_iam_access_key.cicd_user_key.secret
  description = "Secret access key for CI/CD user"
  sensitive   = true
}
