# apprunner ###########################################################################################################

data "aws_region" "current" {}

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

# AWS App Runner ######################################################################################################

resource "aws_apprunner_auto_scaling_configuration_version" "corporate_website_auto_scaling" {
  auto_scaling_configuration_name = "cw-asc-${data.aws_region.current.region}"

  max_concurrency = var.auto_scaling_max_concurrency
  max_size        = var.auto_scaling_max_size
  min_size        = var.auto_scaling_min_size
}

resource "aws_apprunner_service" "corporate_website" {
  service_name = "corporate-website-${data.aws_region.current.region}"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.role_apprunner_ecr.arn
    }

    image_repository {
      image_identifier      = "${var.repository_url}:${var.image_tag}"
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

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.corporate_website_auto_scaling.arn

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

resource "aws_apprunner_custom_domain_association" "corporate_website_domain" {
  depends_on  = [aws_apprunner_service.corporate_website]
  service_arn = aws_apprunner_service.corporate_website.arn
  domain_name = "corporate-website.${var.domain_name}"
  enable_www_subdomain = true
}

# AWS Route53 #########################################################################################################

resource "aws_route53_record" "apprunner_validation_records" {
  count = 3

  zone_id = var.zone_id
  name    = tolist(aws_apprunner_custom_domain_association.corporate_website_domain.certificate_validation_records)[count.index].name
  type    = tolist(aws_apprunner_custom_domain_association.corporate_website_domain.certificate_validation_records)[count.index].type
  records = [tolist(aws_apprunner_custom_domain_association.corporate_website_domain.certificate_validation_records)[count.index].value]
  ttl     = 300
}

resource "aws_route53_record" "apprunner_record" {
  depends_on = [
    aws_apprunner_custom_domain_association.corporate_website_domain,
    aws_route53_record.apprunner_validation_records
  ]

  zone_id        = var.zone_id
  name           = "corporate-website.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  records        = [aws_apprunner_service.corporate_website.service_url]
  set_identifier = "apprunner-${data.aws_region.current.region}-ipv4"

  latency_routing_policy {
    region = data.aws_region.current.region
  }
}
