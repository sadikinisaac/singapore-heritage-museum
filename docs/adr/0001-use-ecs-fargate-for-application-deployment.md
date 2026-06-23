# ADR-0001: Use Amazon ECS Fargate with Amazon ECR and ALB for Application Deployment

## Status

Accepted

## Date

2026-06-20

## Context

The Singapore Heritage Museum project is a DevSecOps capstone application built with Python Flask, Docker, Nginx, GitHub Actions, and Terraform.

The application currently runs successfully in local development using Docker Compose. For the cloud deployment, the team needs a managed AWS deployment model that can run the containerised Flask/Gunicorn application, expose it publicly through a load balancer, support secure secret handling, and integrate with CI/CD and infrastructure-as-code practices.

The team is small, the application is currently a single service, and the system does not yet require a complex distributed microservices platform. The capstone priority is to demonstrate a working, secure, repeatable deployment path rather than introduce unnecessary operational complexity.

The deployment should support:

- Docker image build and push
- Container image storage
- Managed container runtime
- Public HTTP access through a load balancer
- Health checks
- Secrets management
- Cloud logging
- Infrastructure provisioning through Terraform
- Future CI/CD automation

## Decision Drivers

- Small team and limited operational capacity
- Existing Dockerised Flask application
- AWS-based deployment target
- Need for managed compute without managing servers
- Need to avoid unnecessary Kubernetes operational overhead
- Need for integration with ECR, ALB, IAM, Secrets Manager, and CloudWatch
- Capstone requirement to demonstrate DevSecOps practices end-to-end

## Options Considered

### Option 1: EC2 with Docker Compose

Run the application on an EC2 instance using Docker Compose.

**Pros**

- Simple to understand
- Similar to local development
- Full control over the host operating system

**Cons**

- Requires server patching and hardening
- Requires manual scaling and availability design
- Higher Day 2 operations burden
- Less aligned with managed cloud-native deployment practices

### Option 2: Amazon ECS Fargate with ECR and ALB

Build the Docker image, push it to Amazon ECR, and run it on Amazon ECS Fargate behind an Application Load Balancer.

**Pros**

- No EC2 servers to manage
- AWS-native integration with ECR, ALB, IAM, Secrets Manager, and CloudWatch
- Suitable for a small team and single-service application
- Supports health checks and rolling deployments
- Can be provisioned with Terraform
- Easier operational model than Kubernetes

**Cons**

- AWS-specific deployment model
- Less portable than Kubernetes
- Some ECS concepts such as task definitions and services need to be understood

### Option 3: Amazon EKS / Kubernetes

Run the application on Kubernetes using EKS.

**Pros**

- Rich ecosystem for Helm, ArgoCD, service mesh, and Kubernetes-native tooling
- Strong option for larger microservices platforms
- Better portability across cloud providers

**Cons**

- Higher operational complexity
- Requires Kubernetes cluster management knowledge
- Control plane and worker resources add cost
- Not justified for a single-service Flask application at this stage

### Option 4: AWS Lambda / Serverless

Refactor the application into serverless functions behind API Gateway.

**Pros**

- Low cost for spiky or low-volume workloads
- No container or server management
- Scales down to zero

**Cons**

- Requires application restructuring
- Less suitable for the current Flask web application without additional adaptation
- Cold starts and API Gateway integration complexity
- Not the fastest path for the current Dockerised application

## Decision

We will deploy the Singapore Heritage Museum application using **Amazon ECS Fargate with Amazon ECR and an Application Load Balancer**.

The Docker image will be built from the existing `Dockerfile`, pushed to Amazon ECR, and deployed as an ECS Fargate service. The service will be exposed through an internet-facing Application Load Balancer, with the ALB forwarding traffic to the Flask/Gunicorn container on port `5000`.

Terraform will provision the supporting infrastructure, including:

- Amazon ECR repository
- ECS cluster
- ECS task definition
- ECS Fargate service
- Application Load Balancer
- Target group and listener
- Security groups
- IAM task execution role
- IAM task role
- AWS Secrets Manager secret
- CloudWatch log group

## Consequences

### Positive Consequences

- The team avoids managing EC2 servers directly.
- The deployment is more cloud-native than running Docker Compose on a VM.
- The infrastructure can be recreated using Terraform.
- The deployment integrates cleanly with AWS-native services.
- The application can be validated using ALB and ECS health checks.
- The design can later support GitHub Actions CI/CD to build, scan, push, and deploy the image.

