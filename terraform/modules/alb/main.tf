variable "project"    { type = string }
variable "vpc_id"     { type = string }
variable "subnet_ids" { type = list(string) }

resource "aws_security_group" "alb" {
  name   = "${var.project}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5001
    to_port     = 5003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = { Name = "${var.project}-alb" }
}

# ── db-schema (5001) ─────────────────────────────────────────
resource "aws_lb_target_group" "db_schema" {
  name        = "${var.project}-db-schema"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "db_schema" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.db_schema.arn
  }
}

# ── business-logic (5002) ────────────────────────────────────
resource "aws_lb_target_group" "business_logic" {
  name        = "${var.project}-biz-logic"
  port        = 5002
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "business_logic" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5002
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.business_logic.arn
  }
}

# ── api-endpoints (5003) ─────────────────────────────────────
resource "aws_lb_target_group" "api_endpoints" {
  name        = "${var.project}-api-endpoints"
  port        = 5003
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "api_endpoints" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5003
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_endpoints.arn
  }
}

output "dns_name"              { value = aws_lb.main.dns_name }
output "alb_sg_id"             { value = aws_security_group.alb.id }
output "db_schema_tg_arn"      { value = aws_lb_target_group.db_schema.arn }
output "business_logic_tg_arn" { value = aws_lb_target_group.business_logic.arn }
output "api_endpoints_tg_arn"  { value = aws_lb_target_group.api_endpoints.arn }
