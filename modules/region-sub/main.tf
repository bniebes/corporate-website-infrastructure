# region-main #########################################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

data "aws_region" "current" {}

# AWS ECR #############################################################################################################

resource "aws_ecr_repository" "ecr_sub" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = var.ecr_force_delete
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

# AWS App Runner ######################################################################################################

resource "aws_iam_role_policy_attachment" "policy_apprunner_ecr" {
  role       = aws_iam_role.role_apprunner_ecr.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_apprunner_auto_scaling_configuration_version" "corporate_website_auto_scaling" {
  count = var.initial_deployment ? 0 : 1

  auto_scaling_configuration_name = "cw-asc-${data.aws_region.current.region}"

  max_concurrency = var.auto_scaling_max_concurrency
  max_size        = var.auto_scaling_max_size
  min_size        = var.auto_scaling_min_size
}

resource "aws_apprunner_service" "corporate_website" {
  count        = var.initial_deployment ? 0 : 1
  service_name = "corporate-website-${data.aws_region.current.region}"

  source_configuration {

    authentication_configuration {
      access_role_arn = aws_iam_role.role_apprunner_ecr.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.ecr_sub.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"
      image_configuration {
        port = var.port
        runtime_environment_variables = {
          "PORT"   = "${var.port}"
          "REGION" = "${data.aws_region.current.region}"
        }
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

resource "aws_route53_record" "apprunner_domain" {
  count          = var.initial_deployment ? 0 : 1
  zone_id        = var.zone_id
  name           = var.domain_name
  type           = "CNAME"
  ttl            = 60
  records        = [aws_apprunner_service.corporate_website[count.index].service_url]
  set_identifier = data.aws_region.current.region

  latency_routing_policy {
    region = data.aws_region.current.region
  }
}
