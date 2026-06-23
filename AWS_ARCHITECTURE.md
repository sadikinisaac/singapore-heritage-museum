
# AWS Architecture Summary

## AWS Resources Included
- Amazon ECS Fargate
- Amazon ECR
- Application Load Balancer (ALB)
- AWS WAF
- Aurora Serverless PostgreSQL
- AWS Secrets Manager
- AWS CodePipeline
- AWS CodeBuild
- AWS CodeDeploy
- Amazon CloudWatch
- IAM Roles and Policies

## Security Controls
- flake8
- Bandit
- pip-audit
- Trivy
- pytest
- Flask-Talisman
- Flask-Limiter

## Branching Strategy
- dev → CI checks
- staging → staging deployment
- main → production deployment with approval gate
