output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "ECS 퍼블릭 서브넷 ID"
  value       = module.vpc.public_subnet_ids
}

output "private_subnets" {
  description = "RDS 프라이빗 서브넷 ID"
  value       = module.vpc.private_subnet_ids
}

output "ecr_urls" {
  description = "ECR 레포 URL — deploy-fargate.sh 에서 사용"
  value = {
    db_schema      = module.ecr.db_schema_url
    business_logic = module.ecr.business_logic_url
    api_endpoints  = module.ecr.api_endpoints_url
    api_server     = module.ecr.api_server_url
  }
}

output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.rds.endpoint
}

output "alb_dns" {
  description = "ALB DNS — .mcp.json URL로 사용"
  value       = module.alb.dns_name
}

output "bastion_ip" {
  description = "배스천 EC2 퍼블릭 IP (DBeaver SSH 터널용)"
  value       = module.bastion.public_ip
}

output "ecs_cluster" {
  description = "ECS 클러스터명"
  value       = module.ecs.cluster_name
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM Role ARN — GitHub Secrets에 등록"
  value       = module.github_oidc.role_arn
}
