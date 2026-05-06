terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend — 팀 공유 state 필요 시 주석 해제
  # backend "s3" {
  #   bucket         = "rorr-terraform-state"
  #   key            = "mcp-agents/staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   profile        = "rorr-dev"
  #   dynamodb_table = "terraform-lock"
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # 모든 리소스에 자동 태깅 — 콘솔에서 Project=mcp-agents 필터로 한눈에 확인
  default_tags {
    tags = var.tags
  }
}

# ── 모듈 호출 ────────────────────────────────────────────────
module "vpc" {
  source  = "../modules/vpc"
  project = var.project
}

module "iam" {
  source  = "../modules/iam"
  project = var.project
}

module "ecr" {
  source  = "../modules/ecr"
  project = var.project
}

module "rds" {
  source      = "../modules/rds"
  project     = var.project
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  ecs_sg_id      = module.ecs.ecs_sg_id
  bastion_sg_id  = module.bastion.bastion_sg_id
  db_password    = var.db_password
}

module "alb" {
  source     = "../modules/alb"
  project    = var.project
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}

module "bastion" {
  source     = "../modules/bastion"
  project    = var.project
  vpc_id     = module.vpc.vpc_id
  subnet_id  = module.vpc.public_subnet_ids[0]
  rds_sg_id  = module.rds.sg_id
}

module "github_oidc" {
  source       = "../modules/github-oidc"
  project      = var.project
  github_repos = ["woody-rorr/infra", "woody-rorr/v1"]
}

module "ecs" {
  source             = "../modules/ecs"
  project            = var.project
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  aws_region         = var.aws_region

  ecr_db_schema      = module.ecr.db_schema_url
  ecr_business_logic = module.ecr.business_logic_url
  ecr_api_endpoints  = module.ecr.api_endpoints_url
  ecr_api_server     = module.ecr.api_server_url

  rds_url          = "postgresql://mcpadmin:${var.db_password}@${module.rds.endpoint}/${module.rds.db_name}"

  db_schema_tg_arn      = module.alb.db_schema_tg_arn
  business_logic_tg_arn = module.alb.business_logic_tg_arn
  api_endpoints_tg_arn  = module.alb.api_endpoints_tg_arn
  api_server_tg_arn     = module.alb.api_server_tg_arn
  jwt_access_secret     = var.jwt_access_secret
  jwt_refresh_secret    = var.jwt_refresh_secret
  alb_sg_id             = module.alb.alb_sg_id
}
