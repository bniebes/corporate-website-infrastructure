# Main region

## EU, Frankfurt
provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

# Sub regions

## US, Ohio
provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

## US, Oregon
provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

## AP, Mumbai
provider "aws" {
  alias  = "ap-south-1"
  region = "ap-south-1"
}

## AP, Singapur
provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"
}

## AP, Tokyo
provider "aws" {
  alias  = "ap-northeast-1"
  region = "ap-northeast-1"
}

## AP, Sydney
provider "aws" {
  alias  = "ap-southeast-2"
  region = "ap-southeast-2"
}
