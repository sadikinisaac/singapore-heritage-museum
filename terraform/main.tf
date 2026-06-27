# -------------------------------------------------------------------
# Shared naming and tagging
# -------------------------------------------------------------------
locals {
  # Standard resource name pattern, e.g. ianliu-museum-dev
  name = "${var.name_prefix}-${var.environment}"

  # Common tags applied to most AWS resources for tracking and cleanup
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "group-1"
    ManagedBy   = "terraform"
  }
}

# Used for outputs and account validation
data "aws_caller_identity" "current" {}

# -------------------------------------------------------------------
# Amazon ECR
# -------------------------------------------------------------------
# Stores the Docker image that ECS Fargate will run.
resource "aws_ecr_repository" "museum_repo" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  # Enables vulnerability scanning when images are pushed.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Keeps the ECR repository tidy by retaining only the latest 10 images.
resource "aws_ecr_lifecycle_policy" "museum_repo_lifecycle" {
  repository = aws_ecr_repository.museum_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -------------------------------------------------------------------
# CloudWatch Logs
# -------------------------------------------------------------------
# ECS container logs are written here.
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14

  tags = local.common_tags
}

# -------------------------------------------------------------------
# Secrets Manager
# -------------------------------------------------------------------
# Generates a Flask SECRET_KEY and stores it in AWS Secrets Manager.
resource "random_password" "flask_secret_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "app_secret" {
  name                    = "${local.name}-secret-key"
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secret_value" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = random_password.flask_secret_key.result
}

# -------------------------------------------------------------------
# ECS task execution role
# -------------------------------------------------------------------
# This role is worn by ECS when starting the task.
# It allows ECS to pull images from ECR, read secrets, and write logs.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# AWS managed policy for ECS task execution.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allows the ECS execution role to read the Flask secret from Secrets Manager.
resource "aws_iam_role_policy" "ecs_execution_secret_read" {
  name = "${local.name}-execution-secret-read"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.app_secret.arn
      }
    ]
  })
}

# -------------------------------------------------------------------
# ECS task role
# -------------------------------------------------------------------
# This role is worn by the running application container.
# It is separate from the execution role for least-privilege separation.
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Allows the running app task to read the Flask secret if needed.
resource "aws_iam_role_policy" "ecs_task_secret_read" {
  name = "${local.name}-task-secret-read"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.app_secret.arn
      }
    ]
  })
}

# -------------------------------------------------------------------
# Security groups
# -------------------------------------------------------------------
# ALB security group: public HTTP access from the internet.
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "Allow HTTP traffic to the museum ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-alb-sg"
  })
}

# ECS security group: only accepts app traffic from the ALB.
resource "aws_security_group" "ecs_sg" {
  name        = "${local.name}-ecs-sg"
  description = "Allow ALB traffic to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-ecs-sg"
  })
}

# -------------------------------------------------------------------
# Application Load Balancer
# -------------------------------------------------------------------
# Public entry point for users. The ALB forwards traffic to ECS.
resource "aws_lb" "museum_alb" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = local.common_tags
}

# Target group for ECS Fargate tasks.
# target_type = "ip" is required for ECS Fargate awsvpc networking.
resource "aws_lb_target_group" "museum_tg" {
  name        = "${local.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # ALB uses this endpoint to decide if ECS tasks are healthy.
  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

# HTTP listener on port 80.
# For the capstone demo, this forwards HTTP traffic to the ECS target group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.museum_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.museum_tg.arn
  }
}

# -------------------------------------------------------------------
# ECS Fargate
# -------------------------------------------------------------------
# ECS cluster that hosts the Fargate service.
resource "aws_ecs_cluster" "museum_cluster" {
  name = "${local.name}-cluster"

  tags = local.common_tags
}

# ECS task definition describes the container, image, ports, logs, secrets,
# health check, CPU, and memory.
resource "aws_ecs_task_definition" "museum_task" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name = "museum-app"

      # ECS pulls this image from ECR.
      image     = "${aws_ecr_repository.museum_repo.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "FLASK_ENV"
          value = var.flask_env
        },
        {
          name  = "APP_VERSION"
          value = var.image_tag
        }
      ]

      # Injects SECRET_KEY into the container from AWS Secrets Manager.
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = aws_secretsmanager_secret.app_secret.arn
        }
      ]

      # Sends container logs to CloudWatch.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      # Container-level health check.
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=5)\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = local.common_tags
}

# ECS service keeps the desired number of Fargate tasks running
# and registers them with the ALB target group.
resource "aws_ecs_service" "museum_service" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.museum_cluster.id
  task_definition = aws_ecs_task_definition.museum_task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.museum_tg.arn
    container_name   = "museum-app"
    container_port   = var.container_port
  }

  # Ensures listener and ECS execution policy exist before service creation.
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_managed_policy
  ]

  tags = local.common_tags
}

# -------------------------------------------------------------------
# GitHub Actions OIDC provider
# -------------------------------------------------------------------
# Looks up the existing GitHub Actions OIDC provider in AWS.
# This avoids storing long-lived AWS keys in GitHub secrets.
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# -------------------------------------------------------------------
# GitHub Actions deployment IAM role
# -------------------------------------------------------------------
# This role is worn by GitHub Actions during deployment.
# The trust policy controls who can assume the role.
resource "aws_iam_role" "github_actions_deploy_role" {
  name = "${local.name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"

        # The trusted identity provider: GitHub Actions OIDC.
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        }

        # GitHub Actions assumes the role using a web identity token.
        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          # Token must be intended for AWS STS.
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          # Restricts role assumption to approved repo/branch refs.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_actions_allowed_refs
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Permissions granted to GitHub Actions after assuming the deploy role.
resource "aws_iam_role_policy" "github_actions_deploy_policy" {
  name = "${local.name}-github-actions-deploy-policy"
  role = aws_iam_role.github_actions_deploy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthorization"
        Effect = "Allow"

        # Required for Docker login to ECR.
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushImage"
        Effect = "Allow"

        # Allows pushing Docker images only to this project ECR repository.
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.museum_repo.arn
      },
      {
        Sid    = "ECSRedeploy"
        Effect = "Allow"

        # Allows GitHub Actions to trigger a new ECS deployment.
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:UpdateService"
        ]

        # Broad for capstone simplicity; can be tightened to specific ECS ARNs later.
        Resource = "*"
      }
    ]
  })
}

# -------------------------------------------------------------------
# AWS WAF
# -------------------------------------------------------------------
# WAF protects the public ALB before traffic reaches ECS.
resource "aws_wafv2_web_acl" "museum_waf" {
  name        = "${local.name}-waf"
  description = "WAF protection for the Singapore Heritage Museum ALB"
  scope       = "REGIONAL"

  # Allow requests by default unless blocked by managed rules.
  default_action {
    allow {}
  }

  # Common AWS managed web attack protections.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Blocks known malicious input patterns.
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Blocks traffic from IPs with poor AWS reputation signals.
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Enables WAF metrics and sampled request visibility.
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# Attaches the WAF Web ACL to the ALB.
resource "aws_wafv2_web_acl_association" "museum_alb_waf_association" {
  resource_arn = aws_lb.museum_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.museum_waf.arn
}