# -------------------------------------------------------------------
# Account and network outputs
# -------------------------------------------------------------------

output "aws_account_id" {
  description = "AWS account ID where the infrastructure is deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  description = "Existing VPC ID used for the ECS and ALB deployment."
  value       = var.vpc_id
}

output "public_subnet_ids" {
  description = "Existing public subnet IDs used by the ALB and ECS Fargate tasks."
  value       = var.public_subnet_ids
}

# -------------------------------------------------------------------
# ECR outputs
# -------------------------------------------------------------------

output "ecr_repository_name" {
  description = "Name of the ECR repository storing the application Docker image."
  value       = aws_ecr_repository.museum_repo.name
}

output "ecr_repository_url" {
  description = "Full ECR repository URL used for Docker tagging and pushing."
  value       = aws_ecr_repository.museum_repo.repository_url
}

# -------------------------------------------------------------------
# ECS outputs
# -------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running the Fargate service."
  value       = aws_ecs_cluster.museum_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS Fargate service running the museum app."
  value       = aws_ecs_service.museum_service.name
}

# -------------------------------------------------------------------
# ALB and application outputs
# -------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer."
  value       = aws_lb.museum_alb.dns_name
}

output "application_url" {
  description = "Public URL for accessing the museum application."
  value       = "http://${aws_lb.museum_alb.dns_name}"
}

output "health_check_url" {
  description = "Public health check endpoint used to verify the ECS deployment."
  value       = "http://${aws_lb.museum_alb.dns_name}/health"
}

# -------------------------------------------------------------------
# Secrets Manager output
# -------------------------------------------------------------------

output "secret_arn" {
  description = "ARN of the Secrets Manager secret used for the Flask SECRET_KEY."
  value       = aws_secretsmanager_secret.app_secret.arn
}

# -------------------------------------------------------------------
# GitHub Actions OIDC output
# -------------------------------------------------------------------

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC for deployment."
  value       = aws_iam_role.github_actions_deploy_role.arn
}

# -------------------------------------------------------------------
# WAF outputs
# -------------------------------------------------------------------

output "waf_web_acl_name" {
  description = "Name of the AWS WAF Web ACL protecting the public ALB."
  value       = aws_wafv2_web_acl.museum_waf.name
}

output "waf_web_acl_arn" {
  description = "ARN of the AWS WAF Web ACL associated with the ALB."
  value       = aws_wafv2_web_acl.museum_waf.arn
}