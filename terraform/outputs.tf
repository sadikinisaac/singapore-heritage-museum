output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  value = var.vpc_id
}

output "public_subnet_ids" {
  value = var.public_subnet_ids
}

output "ecr_repository_name" {
  value = aws_ecr_repository.museum_repo.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.museum_repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.museum_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.museum_service.name
}

output "alb_dns_name" {
  value = aws_lb.museum_alb.dns_name
}

output "application_url" {
  value = "http://${aws_lb.museum_alb.dns_name}"
}

output "health_check_url" {
  value = "http://${aws_lb.museum_alb.dns_name}/health"
}

output "secret_arn" {
  value = aws_secretsmanager_secret.app_secret.arn
}