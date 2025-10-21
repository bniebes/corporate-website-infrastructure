# corporate-website-infrastructure ####################################################################################

locals {
  sub_regions        = toset(["us-east-2"])
  ecr_force_delete   = true
  domain_name        = "devbn.de"
  initial_deployment = true
  image_name         = "corporate-website"
  image_tag          = "2025-1"
  # Supported combinations for cpu and memory:
  # https://docs.aws.amazon.com/apprunner/latest/dg/architecture.html#architecture.vcpu-memory
  cpu                          = "1 vCPU"
  memory                       = "2 GB"
  auto_scaling_max_concurrency = 200
  auto_scaling_max_size        = 5
  auto_scaling_min_size        = 1
}

# main-region #########################################################################################################

module "main-region-frankfurt" {
  source = "./modules/region-main"
  providers = {
    aws = aws.eu-central-1
  }
  sub_regions                  = local.sub_regions
  ecr_force_delete             = local.ecr_force_delete
  domain_name                  = local.domain_name
  initial_deployment           = local.initial_deployment
  image_name                   = local.image_name
  image_tag                    = local.image_tag
  instance_cpu                 = local.cpu
  instance_memory              = local.memory
  auto_scaling_max_concurrency = local.auto_scaling_max_concurrency
  auto_scaling_max_size        = local.auto_scaling_max_size
  auto_scaling_min_size        = local.auto_scaling_min_size
}

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = module.main-region-frankfurt.hosted_zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone - update these at your domain registrar"
  value       = module.main-region-frankfurt.name_servers
}

output "user_name" {
  description = "IAM username for CI/CD"
  value       = module.main-region-frankfurt.user_name
}

output "user_id" {
  description = "IAM user id for CI/CD"
  value       = module.main-region-frankfurt.user_id
  sensitive   = true
}

output "access_key_id" {
  description = "Access key ID for CI/CD user"
  value       = module.main-region-frankfurt.access_key_id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for CI/CD user"
  value       = module.main-region-frankfurt.secret_access_key
  sensitive   = true
}

# sub-regions ########################################################################################################

## IMPORTANT
## Every region that is declared here has to be put into the set above.
## It is currently not possible to dynamically set providers with a for loop.

module "sub-region-ohio" {
  source = "./modules/region-sub"
  providers = {
    aws = aws.us-east-2
  }
  ecr_force_delete             = local.ecr_force_delete
  domain_name                  = local.domain_name
  zone_id                      = module.main-region-frankfurt.hosted_zone_id
  initial_deployment           = local.initial_deployment
  image_name                   = local.image_name
  image_tag                    = local.image_tag
  instance_cpu                 = local.cpu
  instance_memory              = local.memory
  auto_scaling_max_concurrency = local.auto_scaling_max_concurrency
  auto_scaling_max_size        = local.auto_scaling_max_size
  auto_scaling_min_size        = local.auto_scaling_min_size
}
