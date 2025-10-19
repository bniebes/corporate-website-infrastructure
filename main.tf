# corporate-website-infrastructure ####################################################################################

locals {
  sub_regions = toset(["us-east-2"])
  ecr_force_delete = true
}

# main-region #########################################################################################################

module "main-region-frankfurt" {
  source = "./modules/region-main"
  providers = {
    aws = aws.eu-central-1
  }
  sub_regions = local.sub_regions
  ecr_force_delete = local.ecr_force_delete
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
}
