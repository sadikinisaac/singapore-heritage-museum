variable "aws_region" {
  description = "AWS region for deployment."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project tag/name."
  type        = string
  default     = "singapore-heritage-museum"
}

variable "name_prefix" {
  description = "Short unique prefix for AWS resource names in the shared school account."
  type        = string
  default     = "ianliu-museum"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID for ECS and ALB deployment."
  type        = string
  default     = "vpc-00278f610823b1a74"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB and ECS Fargate tasks."
  type        = list(string)
  default = [
    "subnet-0f5fa81b11e479939",
    "subnet-0f43c3ae03a178f81",
  ]
}

variable "image_tag" {
  description = "Docker image tag to deploy from ECR."
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Container port exposed by the Flask/Gunicorn app."
  type        = number
  default     = 5000
}

variable "desired_count" {
  description = "Number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "flask_env" {
  description = "Flask environment value."
  type        = string
  default     = "production"
}

variable "ecr_force_delete" {
  description = "Allow Terraform destroy to delete the ECR repository even if it contains images."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the GitHub Actions deployment role."
  type        = string
  default     = "sadikinisaac/singapore-heritage-museum"
}

variable "github_actions_allowed_refs" {
  description = "Git refs allowed to assume the GitHub Actions deployment role."
  type        = list(string)
  default = [
    "repo:sadikinisaac/singapore-heritage-museum:ref:refs/heads/dev",
    "repo:sadikinisaac/singapore-heritage-museum:ref:refs/heads/feature/ian-cicd-ecr-ecs"
  ]
}