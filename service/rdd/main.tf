resource "aws_ecs_cluster" "data-apne2-rdd-ecs-cluster-sb" {
  name = "data-apne2-rdd-ecs-cluster-sb"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "data-apne2-rdd-sg-sb" {
  name        = "data-apne2-rdd-sg-sb"
  vpc_id      = "vpc-002382f6a298d90b9"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "data-apne2-rdd-alb-sg-sb" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "data-apne2-rdd-alb-sg-sb"
  description = "Security group for user-service with custom ports open within VPC, and PostgreSQL publicly open"
  vpc_id      = "vpc-002382f6a298d90b9"

  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_rules            = ["https-443-tcp"]
}

module "data-apne2-rdd-ecs-svc-sb" {
  source            = "git::https://github.jobis.co/hjhwang/jnv-ecs-project-sb.git"
  application_name  = "rdd"
  jnv_environment   = "sb"
  vpc_id            = "vpc-002382f6a298d90b9"
  subnet_ids        = ["subnet-0f64339a315bf51dc", "subnet-0a0875073e08a24b7"]
  public_subnet_ids = ["subnet-0a977176fd02ebe78", "subnet-08abb969687d244b4"]
  cluster_arn       = aws_ecs_cluster.data-apne2-rdd-ecs-cluster-sb.arn
  need_loadbalancer = true
  tg_health_check = {
    enabled             = true
    healthy_threshold   = 5
    interval            = 60
    matcher             = "200"
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  alb_certificate_arn = "arn:aws:acm:ap-northeast-2:377428707789:certificate/d9518993-a74b-4f27-8cc8-f0b01d94229c"
  management_sg       = aws_security_group.data-apne2-rdd-sg-sb.id
  container_port      = 5001
  jnv_project         = "data"
}

resource "aws_vpc_security_group_ingress_rule" "example" {
  security_group_id = module.data-apne2-rdd-ecs-svc-sb.alb_sg_id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}


module "data-apne2-rdd-ppl-sb" {
  jnv_project                     = "data"
  source                          = "git::https://github.jobis.co/hjhwang/jnv-ecs-3tier-pipeline.git"
  application_name                = "rdd-ppl"
  jnv_environment                 = "sb"
  pipeline_branch                 = "main"
  build_privileged_mode           = true
  build_image_credential_type     = "CODEBUILD"
  build_image                     = "aws/codebuild/standard:6.0"
  buildspec_name                  = "deploy/sb/buildspec.yml"
  codebuild_vpc_id                = "vpc-002382f6a298d90b9"
  codebuild_vpc_subnets           = ["subnet-0f64339a315bf51dc", "subnet-0a0875073e08a24b7"]
  codebuild_vpc_sg                = [aws_security_group.data-apne2-rdd-sg-sb.id]
  ecs_cluster_name                = "data-apne2-rdd-ecs-cluster-sb"
  ecs_service_name                = module.data-apne2-rdd-ecs-svc-sb.service_name
  secret_arn                      = module.data-apne2-rdd-ecs-svc-sb.secret_arn
  ecs_is_bluegreen                = true
  need_approval                   = true
  codedeploy_app_name             = module.data-apne2-rdd-ecs-svc-sb.codedeploy_app_name
  codedeploy_deploymentgroup_name = module.data-apne2-rdd-ecs-svc-sb.codedeploy_deploymentgroup_name
  ecs_deploy_taskdef_filename     = "deploy/sb/taskdef.json"
  appspec_name                    = "deploy/sb/appspec.yml"
  github_connection_arn           = "arn:aws:codestar-connections:ap-northeast-2:377428707789:connection/8454aa4f-7783-4005-8a8d-5f0290ea3621"
  github_fullrepository_id        = "hjhwang-jobis/RINGDINGDONG"
  pipeline_chatbot_arn            = ""
}
