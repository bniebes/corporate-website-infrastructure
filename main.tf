# corporate-website-infrastructure ####################################################################################

locals {
  sub_regions = toset(["us-east-2"])
  ecr_force_delete = true
  domain_name = "corporate-website.devbn.de"
  # Supported combinations for cpu and memory:
  # https://docs.aws.amazon.com/apprunner/latest/dg/architecture.html#architecture.vcpu-memory
  cpu = "1 vCPU"
  memory = "2 GB"
  auto_scaling_max_concurrency = 200
  auto_scaling_max_size = 5
  auto_scaling_min_size = 1
}

# main-region #########################################################################################################

module "main-region-frankfurt" {
  source = "./modules/region-main"
  providers = {
    aws = aws.eu-central-1
  }
  sub_regions = local.sub_regions
  ecr_force_delete = local.ecr_force_delete
  domain_name = local.domain_name
  # AWS AppRunner
  instance_cpu = local.cpu
  instance_memory = local.memory
  auto_scaling_max_concurrency = local.auto_scaling_max_concurrency
  auto_scaling_max_size = local.auto_scaling_max_size
  auto_scaling_min_size = local.auto_scaling_min_size
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
  ecr_force_delete = local.ecr_force_delete
  domain_name = local.domain_name
  zone_id = module.main-region-frankfurt.hosted_zone_id
  # AWS AppRunner
  instance_cpu = local.cpu
  instance_memory = local.memory
  auto_scaling_max_concurrency = local.auto_scaling_max_concurrency
  auto_scaling_max_size = local.auto_scaling_max_size
  auto_scaling_min_size = local.auto_scaling_min_size
}
