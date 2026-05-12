
output "ecr_repository_url" {
  value = aws_ecr_repository.museum_repo.repository_url
}

output "alb_dns_name" {
  value = aws_lb.museum_alb.dns_name
}
