# corporate-website-infrastructure ####################################################################################

locals {
  sub_regions = toset(["us-east-2"])
  ecr_force_delete = true
  domain_name = "corporate-website.devbn.de"
  cpu = 1024
  memory = 512
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
  instance_cpu = local.cpu
  instance_memory = local.memory
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
  instance_cpu = local.cpu
  instance_memory = local.memory
}
