locals {
  region = "us-west-2"
}

data "terraform_remote_state" "dev-vpc" {
  backend = "s3"
  config = {
    bucket = "jobis-data-ai-stg-tfstate"
    key    = "common/dev-vpc.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "stg-vpc" {
  backend = "s3"
  config = {
    bucket = "jobis-data-ai-stg-tfstate"
    key    = "common/stg-vpc.tfstate"
    region = "ap-northeast-2"
  }
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "data-ai-uwst2-prd"
  cidr = "10.53.0.0/16"

  azs              = ["us-west-2a", "us-west-2b"]
  public_subnets   = ["10.53.0.0/24", "10.53.1.0/24"]
  private_subnets  = ["10.53.100.0/22", "10.53.104.0/22"]
  database_subnets = ["10.53.200.0/24", "10.53.201.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false

  #   enable_vpn_gateway = true

  default_route_table_routes = [

  ]

  tags = {
    TerraformManaged = "true"
    Environment      = "data-ai-prd"
  }
}

resource "aws_route" "dev-route" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.50.0.0/16"
  vpc_peering_connection_id = data.terraform_remote_state.dev-vpc.outputs.vpc_peering_id
}

resource "aws_route" "stg-route" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.51.0.0/16"
  vpc_peering_connection_id = data.terraform_remote_state.stg-vpc.outputs.vpc_peering_id
}

resource "aws_security_group" "bedrock_runtime-sg" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_endpoint" "bedrock-runtime" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.bedrock-runtime"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.bedrock_runtime-sg.id,
  ]

  subnet_ids = module.vpc.private_subnets

  private_dns_enabled = false
}

