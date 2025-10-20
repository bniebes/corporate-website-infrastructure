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

data "aws_region" "current" {}

# Variables #############################################################################################################

variable "ecr_force_delete" {
  type        = bool
  default     = false
  description = "AWS ECR force delete"
}

variable "domain_name" {
  type = string
  description = "Root domain name"
}

variable "zone_id" {
  type = string
  description = "Route53 hosted zone id"
}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_sub" {
  name                 = "ecr-sub"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = var.ecr_force_delete
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

# AWS App Runner ######################################################################################################

resource "aws_iam_role_policy_attachment" "policy_apprunner_ecr" {
  role       = aws_iam_role.role_apprunner_ecr.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

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
      image_identifier      = "${aws_ecr_repository.ecr_sub.repository_url}/corporate-website:prod"
      image_repository_type = "ECR"
      image_configuration {
        port = "30123"
      }
    }

    auto_deployments_enabled = true
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

# AWS Route53 #########################################################################################################

resource "aws_route53_record" "subdomain_sub" {
  zone_id = var.zone_id
  name    = "${data.aws_region.current.region}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_service.corporate_website.service_url]
}

resource "aws_route53_record" "rootdomain_sub" {
  zone_id        = var.zone_id
  name           = var.domain_name
  type           = "CNAME"
  ttl            = 60
  records        = [aws_apprunner_service.corporate_website.service_url]
  set_identifier = data.aws_region.current.region

  latency_routing_policy {
    region = data.aws_region.current.region
  }
}
