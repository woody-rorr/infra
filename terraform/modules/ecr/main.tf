variable "project" { type = string }

resource "aws_ecr_repository" "db_schema" {
  name                 = "${var.project}-db-schema"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "business_logic" {
  name                 = "${var.project}-business-logic"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "api_endpoints" {
  name                 = "${var.project}-api-endpoints"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "api_server" {
  name                 = "${var.project}-api-server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

output "db_schema_url"      { value = aws_ecr_repository.db_schema.repository_url }
output "business_logic_url" { value = aws_ecr_repository.business_logic.repository_url }
output "api_endpoints_url"  { value = aws_ecr_repository.api_endpoints.repository_url }
output "api_server_url"     { value = aws_ecr_repository.api_server.repository_url }
