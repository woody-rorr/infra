variable "project"    { type = string }
variable "vpc_id"     { type = string }
variable "subnet_id"  { type = string }
variable "rds_sg_id"  { type = string }

# 최신 Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# 배스천 보안그룹 — SSH 22 전체 오픈 (IP 고정 불가 환경)
resource "aws_security_group" "bastion" {
  name   = "${var.project}-bastion-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH from anywhere (key-pair auth)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-bastion-sg" }
}

# RDS 보안그룹에 배스천에서 5432 접근 허용
resource "aws_security_group_rule" "bastion_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = var.rds_sg_id
  description              = "bastion to RDS"
}

# EC2 키페어 (로컬에서 생성한 공개키 사용)
resource "aws_key_pair" "bastion" {
  key_name   = "${var.project}-bastion-key"
  public_key = file("${path.module}/bastion_key.pub")
}

# 배스천 EC2 (t3.micro 프리티어)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = { Name = "${var.project}-bastion" }
}

output "public_ip"     { value = aws_instance.bastion.public_ip }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "public_dns" { value = aws_instance.bastion.public_dns }
