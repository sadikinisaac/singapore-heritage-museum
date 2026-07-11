# Monitoring & Break-Fix Guide

## Singapore Heritage Museum DevSecOps Project

This guide covers monitoring, troubleshooting and recovery for the final Singapore Heritage Museum deployment.

Final architecture:
GitHub Actions → OIDC IAM Role → Amazon ECR → Amazon ECS Fargate → ALB → AWS WAF

AWS region:
ap-southeast-1

Key resources:

ECR repository:       ianliu-museum-dev
ECS cluster:          ianliu-museum-dev-cluster
ECS service:          ianliu-museum-dev-service
CloudWatch log group: /ecs/ianliu-museum-dev
Deployment workflow:  CD - Build, Scan and Deploy to ECS
Workflow file:        .github/workflows/deploy-ecs.yml

---

# Part 1 — Monitoring the System

## 1. Check GitHub Actions CI/CD Health

Purpose: Confirm that the latest build, security scan, image push and ECS deployment succeeded.

Go to:
GitHub → Actions → CD - Build, Scan and Deploy to ECS

Expected successful stages:

Checkout repository                         ✅
Configure AWS credentials using OIDC        ✅
Login to Amazon ECR                         ✅
Build Docker image                          ✅
Scan Docker image with Trivy                ✅
Push Docker image to ECR                    ✅
Force ECS service redeployment              ✅
Wait for ECS service to become stable       ✅
Notify Discord                              ✅

The final deployment workflow is:
.github/workflows/deploy-ecs.yml

The old staging/production workflows are not part of the final deployment path.

---

## 2. Check AWS CLI Identity

Purpose: Confirm that the AWS CLI is authenticated to the correct AWS account.

aws sts get-caller-identity

Expected account:
255945442255

If the account ID is different, switch credentials/profile before troubleshooting further.

---

## 3. Check ECR Repository Health

Purpose: Confirm that the Docker image repository exists and contains pushed images.

Check that the repository exists:
aws ecr describe-repositories \
  --repository-names ianliu-museum-dev \
  --region ap-southeast-1

List images:
aws ecr describe-images \
  --repository-name ianliu-museum-dev \
  --region ap-southeast-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[*].{Tags:imageTags,PushedAt:imagePushedAt,Size:imageSizeInBytes}' \
  --output table


Check whether the `latest` tag exists:
aws ecr describe-images \
  --repository-name ianliu-museum-dev \
  --image-ids imageTag=latest \
  --region ap-southeast-1


Check the latest pushed image:
aws ecr describe-images \
  --repository-name ianliu-museum-dev \
  --region ap-southeast-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].{Tags:imageTags,PushedAt:imagePushedAt,Digest:imageDigest}' \
  --output table

---

## 4. Check ECS Service Health

Purpose: Confirm that the ECS Fargate service exists and is running the desired task count.

aws ecs describe-services \
  --cluster ianliu-museum-dev-cluster \
  --services ianliu-museum-dev-service \
  --region ap-southeast-1 \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,TaskDefinition:taskDefinition}' \
  --output table

Expected:
Status:   ACTIVE
Desired:  1
Running:  1
Pending:  0

List running tasks:
aws ecs list-tasks \
  --cluster ianliu-museum-dev-cluster \
  --service-name ianliu-museum-dev-service \
  --region ap-southeast-1

---

## 5. Check ALB Target Group Health

Purpose: Confirm that the Application Load Balancer can reach the ECS task.

Get the target group ARN:

TG_ARN=$(aws elbv2 describe-target-groups \
  --names ianliu-museum-dev-tg \
  --region ap-southeast-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo $TG_ARN

Check target health:
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --region ap-southeast-1 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

Expected:
State: healthy

If the target is unhealthy, check ECS logs and the `/health` endpoint.

---

## 6. Check Application Health Endpoint

Purpose: Confirm that the application is responding through the public ALB.

From the Terraform directory:

cd terraform
terraform output -raw health_check_url
curl $(terraform output -raw health_check_url)

Expected response:
json
{
  "status": "healthy",
  "service": "singapore-heritage-museum",
  "environment": "production"
}

---

## 7. Check CloudWatch Logs

Purpose: View runtime logs from the ECS container.

Tail recent logs:

aws logs tail /ecs/ianliu-museum-dev \
  --region ap-southeast-1 \
  --since 30m

Follow logs live:

aws logs tail /ecs/ianliu-museum-dev \
  --region ap-southeast-1 \
  --follow

Use this when investigating:

Application crashes
HTTP 500 errors
Failed health checks
Container startup failures
Missing environment variables or secrets

---

## 8. Check AWS WAF

Purpose: Confirm that the WAF Web ACL exists and is available.

aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region ap-southeast-1 \
  --query 'WebACLs[*].{Name:Name,Id:Id,ARN:ARN}' \
  --output table

Expected Web ACL:
ianliu-museum-dev-waf

The WAF is associated with the public ALB and uses AWS managed rule groups.

---

## 9. Check Terraform Outputs

Purpose: Confirm the current infrastructure values after `terraform apply`.

cd terraform
terraform output

Useful outputs:
application_url
health_check_url
ecr_repository_url
ecs_cluster_name
ecs_service_name
vpc_id
public_subnet_ids
internet_gateway_id
public_route_table_id
waf_web_acl_name
waf_web_acl_arn
github_actions_role_arn

---

# Part 2 — Break-Fix Guide

## Scenario 1: GitHub Actions Cannot Authenticate to AWS

Symptom:
Credentials could not be loaded

Likely causes:
AWS_ROLE_ARN secret is missing
Workflow does not have OIDC permission
IAM role trust policy does not allow main
Workflow was run from a branch other than main

Check GitHub secret:
Settings → Secrets and variables → Actions → AWS_ROLE_ARN

Expected value:
arn:aws:iam::255945442255:role/ianliu-museum-dev-github-actions-role

Check workflow permissions:
permissions:
  id-token: write
  contents: read

Check role assumption step:
role-to-assume: ${{ secrets.AWS_ROLE_ARN }}

Check IAM trust policy allows:
repo:sadikinisaac/singapore-heritage-museum:ref:refs/heads/main


Fix:
Correct the GitHub secret, workflow YAML, or IAM trust policy.
Then rerun the workflow from main.

---

## Scenario 2: ECR Repository Missing

Symptom:
name unknown: The repository with name 'ianliu-museum-dev' does not exist

Cause:
The school AWS sandbox may have deleted the ECR repository.

Check:
aws ecr describe-repositories \
  --repository-names ianliu-museum-dev \
  --region ap-southeast-1

Fix:
cd terraform
terraform apply

Then rerun:
GitHub → Actions → CD - Build, Scan and Deploy to ECS → Run workflow → main

---

## Scenario 3: Image Missing From ECR

Symptom:
ECS cannot pull image
ImageNotFoundException
CannotPullContainerError

Check ECR images:
aws ecr describe-images \
  --repository-name ianliu-museum-dev \
  --region ap-southeast-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].{Tags:imageTags,PushedAt:imagePushedAt,Digest:imageDigest}' \
  --output table

Fix:
Rerun the GitHub Actions deployment workflow from main.

This will rebuild, scan, push the image to ECR and redeploy ECS.

---

## Scenario 4: ALB Cannot Be Created

Symptom:
InvalidSubnet: VPC has no internet gateway

Cause:
The VPC does not have a valid Internet Gateway route, or the previous school VPC route became blackholed.

Fix:
The project Terraform now manages the VPC, Internet Gateway, public subnets and public route table.

Run:
cd terraform
terraform apply

Verify route table:
aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw public_route_table_id) \
  --region ap-southeast-1 \
  --query "RouteTables[].Routes[]" \
  --output table

Expected route:
0.0.0.0/0 → igw-xxxxxxxx → active

---

## Scenario 5: ECS Service Is Not Running

Check service state:
aws ecs describe-services \
  --cluster ianliu-museum-dev-cluster \
  --services ianliu-museum-dev-service \
  --region ap-southeast-1 \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table

Check recent ECS service events:
aws ecs describe-services \
  --cluster ianliu-museum-dev-cluster \
  --services ianliu-museum-dev-service \
  --region ap-southeast-1 \
  --query 'services[0].events[0:5].{Time:createdAt,Message:message}' \
  --output table

Check logs:
aws logs tail /ecs/ianliu-museum-dev \
  --region ap-southeast-1 \
  --since 30m

Common causes:
Image missing from ECR
Task cannot pull image
SECRET_KEY secret missing
Container health check failing
ALB target group health check failing

Fix:
cd terraform
terraform apply

Then rerun the GitHub Actions deployment workflow from `main`.

---

## Scenario 6: ALB Target Group Is Unhealthy

Check target health:
TG_ARN=$(aws elbv2 describe-target-groups \
  --names ianliu-museum-dev-tg \
  --region ap-southeast-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --region ap-southeast-1 \
  --output table

Check application health:
curl $(terraform output -raw health_check_url)

Check logs:
aws logs tail /ecs/ianliu-museum-dev \
  --region ap-southeast-1 \
  --since 30m

Likely causes:
Container is not listening on port 5000
/health endpoint is failing
Task is still starting
Security group issue
Application crash

Fix according to cause:
If app crash: inspect CloudWatch logs
If image issue: rerun GitHub Actions deployment
If infra issue: rerun terraform apply
If security group issue: check ALB SG and ECS SG in Terraform

---

## Scenario 7: Application Returns 500 Error

Check CloudWatch logs:
aws logs tail /ecs/ianliu-museum-dev \
  --region ap-southeast-1 \
  --since 30m

Check latest GitHub commit:
git log --oneline -5

Fix:
Identify the faulty code change.
Create a fix or revert the bad commit.
Push to main through PR.
Rerun GitHub Actions deployment.

Rollback example:
git revert <bad-commit-hash>
git push origin main

---

## Scenario 8: Bad Deployment / Rollback Required

Preferred rollback method:
git log --oneline
git revert <bad-commit-hash>
git push origin main

Then the deployment workflow will:
Build image
Run Trivy scan
Push to ECR
Redeploy ECS
Wait for ECS stability

Alternative:
Rerun a previous successful GitHub Actions workflow if the image still exists in ECR.

---

## Scenario 9: School Sandbox Deleted AWS Resources

Symptoms:
Terraform detected changes made outside of Terraform

or missing resources such as:
ECR repository
ECS cluster
ECS service
ALB
Target group
CloudWatch log group
Secrets Manager secret
WAF Web ACL
VPC
Internet Gateway
Route table

Fix:
cd terraform
terraform plan
terraform apply

Then rerun deployment:
GitHub → Actions → CD - Build, Scan and Deploy to ECS → Run workflow → main

Then verify:
curl $(terraform output -raw health_check_url)

This is the standard recovery process before presentation or demo.

---

# Quick Decision Matrix

| Problem                                   | Check First                       | Likely Fix                               |
| ----------------------------------------- | --------------------------------- | ---------------------------------------- |
| GitHub Actions cannot authenticate to AWS | `AWS_ROLE_ARN`, OIDC trust policy | Fix secret or IAM trust policy           |
| ECR repository missing                    | `aws ecr describe-repositories`   | `terraform apply`                        |
| Image missing from ECR                    | `aws ecr describe-images`         | Rerun GitHub Actions deploy              |
| ALB cannot be created                     | VPC route table and IGW           | `terraform apply`                        |
| ECS service not running                   | `aws ecs describe-services`       | Check logs, rerun deploy                 |
| Target group unhealthy                    | `describe-target-health`          | Check `/health`, port 5000, logs         |
| App error                                 | CloudWatch logs                   | Fix app, commit, rerun pipeline          |
| Bad deployment                            | Git history / GitHub run          | `git revert`, rerun pipeline             |
| Sandbox cleanup                           | Terraform plan                    | `terraform apply`, then rerun deployment |

---

# Useful Environment Variables

Optional shell helpers:
export AWS_REGION=ap-southeast-1
export ECR_REPOSITORY=ianliu-museum-dev
export ECR_ACCOUNT_ID=255945442255
export ECR_URI=$ECR_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY
export ECS_CLUSTER=ianliu-museum-dev-cluster
export ECS_SERVICE=ianliu-museum-dev-service

Quick ECR health check:
aws ecr describe-images \
  --repository-name $ECR_REPOSITORY \
  --region $AWS_REGION \
  --query "sort_by(imageDetails,& imagePushedAt)[-1].{Tags:imageTags,PushedAt:imagePushedAt,Digest:imageDigest}" \
  --output table

Quick ECS health check:
aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region $AWS_REGION \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table

Quick logs check:
aws logs tail /ecs/ianliu-museum-dev \
  --region $AWS_REGION \
  --since 30m

---

# Notes

Production runtime is ECS Fargate, not local Docker Compose.

Local Docker commands such as `docker ps`, `docker logs`, and `docker compose up` are useful for local development, but production monitoring and break-fix should use:

GitHub Actions
Amazon ECR
Amazon ECS
Application Load Balancer
AWS WAF
CloudWatch Logs
Terraform

The project does not rely on long-lived AWS access keys. Deployment uses GitHub Actions OIDC and the `AWS_ROLE_ARN` repository secret.
