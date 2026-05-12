
provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "museum_repo" {
  name = "singapore-heritage-museum"
}

resource "aws_ecs_cluster" "museum_cluster" {
  name = "museum-cluster"
}

resource "aws_lb" "museum_alb" {
  name               = "museum-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
}

resource "aws_wafv2_web_acl_association" "museum_waf" {
  resource_arn = aws_lb.museum_alb.arn
  web_acl_arn  = var.waf_acl_arn
}

resource "aws_secretsmanager_secret" "app_secret" {
  name = "museum-secret-key"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/museum-app"
}

resource "aws_db_subnet_group" "aurora_subnets" {
  name       = "museum-db-subnets"
  subnet_ids = var.private_subnets
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "museum-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.aurora_subnets.name
  skip_final_snapshot     = true
}

resource "aws_ecs_service" "museum_service" {
  name            = "museum-service"
  cluster         = aws_ecs_cluster.museum_cluster.id
  task_definition = var.task_definition_arn
  desired_count   = 2
  launch_type     = "FARGATE"
}
