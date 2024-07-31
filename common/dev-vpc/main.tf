locals {
  region             = "ap-northeast-2"
  transit_gateway_id = "tgw-051aafe0af89ad9cb" # 185236431346
}

data "terraform_remote_state" "uwst2-vpc" {
  backend = "s3"
  config = {
    bucket = "jobis-data-ai-stg-tfstate"
    key    = "common/uwst2-vpc.tfstate"
    region = "ap-northeast-2"
  }
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "data-ai-apne2-dev"
  cidr = "10.50.0.0/16"

  azs              = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets   = ["10.50.0.0/24", "10.50.1.0/24"]
  private_subnets  = ["10.50.100.0/22", "10.50.104.0/22"]
  database_subnets = ["10.50.200.0/24", "10.50.201.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false

  #   enable_vpn_gateway = true

  default_route_table_routes = [
    {
      cidr_block         = "10.0.0.0/16" # jobis-dev sec
      transit_gateway_id = local.transit_gateway_id
    },
    {
      cidr_block         = "10.10.17.0/24" # jobis-data-stg dev
      transit_gateway_id = local.transit_gateway_id
    },
  ]

  tags = {
    TerraformManaged = "true"
    Environment      = "data-ai-dev"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "sec-data-ai-dev-vpc-tgw-attachment" {
  transit_gateway_id = local.transit_gateway_id
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id

  tags = {
    Name = "sec-apne2-data-ai-dev-vpc-att"
  }
}

## routes
resource "aws_route" "prv-subnet-jobis-dev-sec" {
  route_table_id         = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "10.0.0.0/16" # jobis-dev sec
  transit_gateway_id     = local.transit_gateway_id
}

resource "aws_route" "prv-subnet-jobis-data-stg-dev" {
  route_table_id         = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "10.10.17.0/24" # jobis-data-stg dev
  transit_gateway_id     = local.transit_gateway_id
}

resource "aws_vpc_peering_connection" "data-ai-us-west-2-peer" {
  peer_owner_id = data.aws_caller_identity.current.account_id
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = data.terraform_remote_state.uwst2-vpc.outputs.vpc_id
  peer_region   = "us-west-2"
  auto_accept   = false
}

provider "aws" {
  alias  = "peer"
  region = "us-west-2"

  # Accepter's credentials.
}


resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.data-ai-us-west-2-peer.id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}

resource "aws_vpc_peering_connection_options" "requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider = aws.peer

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "uwst2-route" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.53.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.data-ai-us-west-2-peer.id
}
