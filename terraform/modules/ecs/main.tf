variable "project"            { type = string }
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }
variable "execution_role_arn" { type = string }
variable "task_role_arn"      { type = string }
variable "aws_region"         { type = string }

variable "ecr_db_schema"      { type = string }
variable "ecr_business_logic" { type = string }
variable "ecr_api_endpoints"  { type = string }
variable "ecr_api_server"        { type = string }
variable "jwt_access_secret" {
  type      = string
  sensitive = true
}
variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}

variable "rds_url"            { type = string }

variable "db_schema_tg_arn"      { type = string }
variable "business_logic_tg_arn" { type = string }
variable "api_endpoints_tg_arn"  { type = string }
variable "api_server_tg_arn"     { type = string }
variable "alb_sg_id"             { type = string }

# ── CloudWatch 로그 ───────────────────────────────────────────
resource "aws_cloudwatch_log_group" "mcp" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

# ── ECS 클러스터 ─────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"
}

# ── 보안 그룹 ────────────────────────────────────────────────
resource "aws_security_group" "ecs_tasks" {
  name   = "${var.project}-ecs-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ecs-sg"
  }
}

resource "aws_security_group_rule" "mcp_ingress" {
  type                     = "ingress"
  from_port                = 5001
  to_port                  = 5003
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "MCP ports from ALB only"
}

resource "aws_security_group_rule" "api_server_ingress" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "api-server port from ALB only"
}

# ── Task Definition (서비스 공통 패턴) ─────────────────────
locals {
  log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.mcp.name
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "ecs"
    }
  }

}

resource "aws_ecs_task_definition" "db_schema" {
  family                   = "${var.project}-db-schema"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "db-schema"
      image     = "${var.ecr_db_schema}:latest"
      essential = true
      portMappings     = [{ containerPort = 5001 }]
      logConfiguration = local.log_config
      environment = [
        { name = "RDS_URL", value = var.rds_url }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "business_logic" {
  family                   = "${var.project}-business-logic"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "business-logic"
      image     = "${var.ecr_business_logic}:latest"
      essential = true
      portMappings     = [{ containerPort = 5002 }]
      logConfiguration = local.log_config
    }
  ])
}

resource "aws_ecs_task_definition" "api_endpoints" {
  family                   = "${var.project}-api-endpoints"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api-endpoints"
      image     = "${var.ecr_api_endpoints}:latest"
      essential = true
      portMappings     = [{ containerPort = 5003 }]
      logConfiguration = local.log_config
    }
  ])
}

# ── ECS Services ────────────────────────────────────────────
resource "aws_ecs_service" "db_schema" {
  name                   = "${var.project}-db-schema"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.db_schema.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.db_schema_tg_arn
    container_name   = "db-schema"
    container_port   = 5001
  }

  lifecycle { ignore_changes = [desired_count] }
}

resource "aws_ecs_service" "business_logic" {
  name                   = "${var.project}-business-logic"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.business_logic.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.business_logic_tg_arn
    container_name   = "business-logic"
    container_port   = 5002
  }

  lifecycle { ignore_changes = [desired_count] }
}

resource "aws_ecs_service" "api_endpoints" {
  name                   = "${var.project}-api-endpoints"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.api_endpoints.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.api_endpoints_tg_arn
    container_name   = "api-endpoints"
    container_port   = 5003
  }

  lifecycle { ignore_changes = [desired_count] }
}

# ── Auto Scaling ─────────────────────────────────────────────
resource "aws_appautoscaling_target" "db_schema" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.db_schema.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "db_schema_cpu" {
  name               = "${var.project}-db-schema-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.db_schema.resource_id
  scalable_dimension = aws_appautoscaling_target.db_schema.scalable_dimension
  service_namespace  = aws_appautoscaling_target.db_schema.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_target" "business_logic" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.business_logic.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "business_logic_cpu" {
  name               = "${var.project}-business-logic-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.business_logic.resource_id
  scalable_dimension = aws_appautoscaling_target.business_logic.scalable_dimension
  service_namespace  = aws_appautoscaling_target.business_logic.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_target" "api_endpoints" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_endpoints.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_endpoints_cpu" {
  name               = "${var.project}-api-endpoints-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_endpoints.resource_id
  scalable_dimension = aws_appautoscaling_target.api_endpoints.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_endpoints.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── api-server Task Definition ───────────────────────────────
resource "aws_ecs_task_definition" "api_server" {
  family                   = "${var.project}-api-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api-server"
      image     = "${var.ecr_api_server}:latest"
      essential = true
      portMappings     = [{ containerPort = 3000 }]
      logConfiguration = local.log_config
      environment = [
        { name = "DATABASE_URL",       value = var.rds_url },
        { name = "JWT_ACCESS_SECRET",  value = var.jwt_access_secret },
        { name = "JWT_REFRESH_SECRET", value = var.jwt_refresh_secret }
      ]
    }
  ])
}

resource "aws_ecs_service" "api_server" {
  name                   = "${var.project}-api-server"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.api_server.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.api_server_tg_arn
    container_name   = "api-server"
    container_port   = 3000
  }

  lifecycle { ignore_changes = [desired_count] }
}

resource "aws_appautoscaling_target" "api_server" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_server.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_server_cpu" {
  name               = "${var.project}-api-server-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_server.resource_id
  scalable_dimension = aws_appautoscaling_target.api_server.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_server.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

output "cluster_name" { value = aws_ecs_cluster.main.name }
output "ecs_sg_id"    { value = aws_security_group.ecs_tasks.id }
