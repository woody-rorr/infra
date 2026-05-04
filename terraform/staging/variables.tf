variable "aws_profile" {
  default = "rorr-dev"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "project" {
  default = "mcp-agents-staging"
}

variable "db_password" {
  description = "RDS 패스워드 — terraform apply 시 입력 또는 TF_VAR_db_password 환경변수"
  type        = string
  sensitive   = true
}

variable "jwt_access_secret" {
  description = "JWT Access Token 서명 키"
  type        = string
  sensitive   = true
}

variable "jwt_refresh_secret" {
  description = "JWT Refresh Token 서명 키"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "모든 리소스에 적용되는 공통 태그"
  type        = map(string)
  default = {
    Project     = "mcp-agents"
    Environment = "staging"
    ManagedBy   = "terraform"
    Owner       = "rorr-dev"
  }
}
