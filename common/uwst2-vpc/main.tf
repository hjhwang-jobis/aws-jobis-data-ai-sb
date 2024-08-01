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

## bedrock endpoint security group
resource "aws_security_group" "bedrock-endpoint-sg" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "bedrock-endpoint-sg-https-ingress-dev" {
  security_group_id = aws_security_group.bedrock-endpoint-sg.id

  cidr_ipv4   = "10.50.0.0/16"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "bedrock-endpoint-sg-https-ingress-stg" {
  security_group_id = aws_security_group.bedrock-endpoint-sg.id

  cidr_ipv4   = "10.51.0.0/16"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

## Private Hosted Zone
resource "aws_route53_zone" "stg-data-ai-bedrock-jobis-internal" {
  name = "stg.data-ai-bedrock.jobis.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_zone_association" "dev-vpc" {
  zone_id    = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  vpc_id     = data.terraform_remote_state.dev-vpc.outputs.vpc_id
  vpc_region = "ap-northeast-2"
}

resource "aws_route53_zone_association" "stg-vpc" {
  zone_id    = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  vpc_id     = data.terraform_remote_state.stg-vpc.outputs.vpc_id
  vpc_region = "ap-northeast-2"
}

## Bedrock Runtime VPC Endpoint
resource "aws_vpc_endpoint" "bedrock-runtime" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.bedrock-runtime"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.bedrock-endpoint-sg.id,
  ]

  subnet_ids = module.vpc.private_subnets

  private_dns_enabled = false
}

resource "aws_route53_record" "bedrock-runtime" {
  zone_id = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  name    = "bedrock-runtime.stg.data-ai-bedrock.jobis.internal"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.bedrock-runtime.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.bedrock-runtime.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

## Bedrock VPC Endpoint
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.bedrock"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.bedrock-endpoint-sg.id,
  ]

  subnet_ids = module.vpc.private_subnets

  private_dns_enabled = false
}

resource "aws_route53_record" "bedrock" {
  zone_id = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  name    = "bedrock.stg.data-ai-bedrock.jobis.internal"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.bedrock.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.bedrock.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

## Bedrock Agent VPC Endpoint
resource "aws_vpc_endpoint" "bedrock-agent" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.bedrock-agent"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.bedrock-endpoint-sg.id,
  ]

  subnet_ids = module.vpc.private_subnets

  private_dns_enabled = false
}

resource "aws_route53_record" "bedrock-agent" {
  zone_id = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  name    = "bedrock-agent.stg.data-ai-bedrock.jobis.internal"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.bedrock-agent.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.bedrock-agent.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

## Bedrock Agent Runtime VPC Endpoint
resource "aws_vpc_endpoint" "bedrock-agent-runtime" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.bedrock-agent-runtime"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.bedrock-endpoint-sg.id,
  ]

  subnet_ids = module.vpc.private_subnets

  private_dns_enabled = false
}

resource "aws_route53_record" "bedrock-agent-runtime" {
  zone_id = aws_route53_zone.stg-data-ai-bedrock-jobis-internal.zone_id
  name    = "bedrock-agent-runtime.stg.data-ai-bedrock.jobis.internal"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.bedrock-agent-runtime.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.bedrock-agent-runtime.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}
