# ☁️ AWS Cloud Service Guide: Deploying a Scalable Microservices Architecture

### *Mapping every layer of the solution architecture to AWS-native services*

> **Author:** *Renato Barufi* | **Domain:** Solution Architecture · AWS Cloud | **Reading time:** ~18 min
> **Companion to:** [Software Architecture Model: Scalable Microservices with Frontend + Backend](./software-architecture.md)

---

## Introduction

The [architecture model](./software-architecture.md) defines **what** to build: a frontend, an API gateway, independent microservices, and a data layer — all containerized and independently deployable. This guide answers **how to run it on AWS**.

Every layer of the solution maps directly to one or more AWS-managed services. The goal is to replace self-managed infrastructure (your own Kubernetes cluster, your own database servers, your own message broker) with **AWS equivalents that scale automatically, handle availability, and reduce operational overhead**.

---

## 1. 📐 Architecture Mapping: Local → AWS

The table below translates the generic solution components into AWS services:

| Solution Component | Local / Generic | AWS Service |
|---|---|---|
| **Frontend hosting** | Docker container (Next.js) | AWS Amplify or CloudFront + S3 |
| **API Gateway / BFF** | Kong / custom Node.js | Amazon API Gateway + AWS Lambda or ECS |
| **Microservices (containers)** | Docker + Kubernetes | Amazon ECS (Fargate) or Amazon EKS |
| **Container image registry** | Docker Hub / local registry | Amazon ECR |
| **PostgreSQL** | Postgres container | Amazon RDS (PostgreSQL) |
| **Redis cache** | Redis container | Amazon ElastiCache (Redis) |
| **MongoDB** | MongoDB container | Amazon DocumentDB |
| **Message Queue** | RabbitMQ container | Amazon SQS + Amazon SNS |
| **Async event streaming** | Kafka | Amazon MSK (Managed Kafka) |
| **Secrets & config** | `.env` files | AWS Secrets Manager + AWS SSM Parameter Store |
| **CI/CD pipeline** | GitHub Actions | AWS CodePipeline + CodeBuild |
| **Infrastructure as code** | Terraform / K8s YAML | AWS CDK or Terraform (AWS provider) |
| **DNS + TLS** | Local certs / nginx | Amazon Route 53 + AWS Certificate Manager |
| **Logging** | stdout / ELK stack | Amazon CloudWatch Logs |
| **Monitoring & metrics** | Prometheus / Grafana | Amazon CloudWatch + AWS X-Ray |

---

## 2. 🏗️ Full AWS Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                          USER (Browser)                            │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ HTTPS
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                     Amazon Route 53 (DNS)                          │
│                   AWS Certificate Manager (TLS)                    │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
              ┌────────────────┴───────────────┐
              │                                │
              ▼                                ▼
┌─────────────────────────┐      ┌─────────────────────────────────┐
│   Amazon CloudFront     │      │      AWS Amplify Hosting        │
│   + S3 Static Bucket    │  OR  │   (Next.js SSR / SSG / ISR)     │
│   (Static SPA export)   │      │   (full Next.js features)       │
└────────────┬────────────┘      └────────────────┬────────────────┘
             │                                    │
             └──────────────┬─────────────────────┘
                            │ REST / GraphQL (HTTPS)
                            ▼
┌────────────────────────────────────────────────────────────────────┐
│                    Amazon API Gateway (HTTP API)                   │
│         Auth (JWT/Cognito) · Rate Limiting · CORS · Routing        │
└───────────────┬──────────────────┬───────────────┬────────────────┘
                │                  │               │
                ▼                  ▼               ▼
┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐
│   ECS Fargate    │  │   ECS Fargate     │  │   ECS Fargate         │
│   service-auth   │  │   service-orders  │  │ service-notifications │
│   (Node.js)      │  │   (Go)            │  │   (Python/FastAPI)    │
│   Auto Scaling   │  │   Auto Scaling    │  │   Auto Scaling        │
└────────┬─────────┘  └────────┬──────────┘  └──────────┬────────────┘
         │                     │                         │
         └─────────────────────┼─────────────────────────┘
                               │
         ┌─────────────────────┼──────────────────────┐
         ▼                     ▼                      ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│  Amazon RDS     │  │ Amazon           │  │  Amazon SQS / SNS    │
│  (PostgreSQL)   │  │ ElastiCache      │  │  (Message Queuing)   │
│  Multi-AZ       │  │ (Redis)          │  │  (Notifications)     │
└─────────────────┘  └──────────────────┘  └──────────────────────┘
```

---

## 3. 🌐 Frontend: CloudFront + S3 vs. AWS Amplify

You have two solid options for hosting the Next.js frontend on AWS.

### Option A — Amazon CloudFront + S3 (Static export)

Best when the frontend is a **pure SPA or a statically exported Next.js site** (no SSR needed).

```
User → CloudFront (CDN, global edge) → S3 Bucket (HTML/JS/CSS assets)
```

**Setup:**
1. Build: `next export` → generates static files in `/out`
2. Upload to an S3 bucket (versioned, private)
3. CloudFront distribution points to the S3 bucket as origin
4. ACM certificate attached to CloudFront for HTTPS
5. Route 53 `A` record → CloudFront distribution

**Terraform snippet:**
```hcl
resource "aws_s3_bucket" "frontend" {
  bucket = "my-app-frontend-prod"
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "s3-frontend"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
}
```

### Option B — AWS Amplify Hosting (Full Next.js)

Best when using **Next.js SSR, API routes, ISR (Incremental Static Regeneration)**, or middleware.

```
User → Amplify CDN → Amplify compute (SSR Lambda@Edge) → S3 (assets)
```

**Setup:**
1. Connect your GitHub repo to Amplify
2. Amplify detects Next.js automatically and configures build/deploy
3. Custom domain + HTTPS configured in the Amplify console
4. Environment variables set per branch (staging, production)

> 💡 **When to choose which:**
> - Use **Amplify** if you need SSR, API routes, or ISR — it handles Next.js natively without extra config.
> - Use **CloudFront + S3** if you have a pure static export and want maximum control and lower cost.

---

## 4. 🔀 API Gateway: Amazon API Gateway (HTTP API)

**Amazon API Gateway** replaces your self-managed API Gateway or BFF layer.

### Why HTTP API (not REST API)?

API Gateway offers two modes. For microservices frontends:

| Feature | HTTP API | REST API |
|---|---|---|
| **Latency** | ~1ms lower | Higher overhead |
| **Cost** | ~70% cheaper | More expensive |
| **JWT Authorizer** | ✅ Native | Requires Lambda |
| **CORS** | ✅ Built-in | Manual |
| **WebSocket** | ❌ (use REST) | ✅ |

Use **HTTP API** for standard REST/GraphQL routing to ECS services. Use **REST API** only if you need WebSockets or full request/response transformation.

### Routing to ECS services:

```
POST /auth/*      → http://service-auth.internal:5001
GET  /orders/*    → http://service-orders.internal:5002
POST /notify/*    → http://service-notifications.internal:5003
```

### Cognito JWT Authorizer:

```yaml
# api-gateway-config (CDK / Terraform equivalent)
authorizer:
  type: JWT
  identity_source: "$request.header.Authorization"
  jwt_configuration:
    audience: ["my-app-client-id"]
    issuer: "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX"
```

Every route protected by this authorizer validates the JWT against **Amazon Cognito** — no custom auth middleware needed in your microservices.

---

## 5. 📦 Container Hosting: ECS Fargate vs. EKS

Both services run your Docker containers on AWS. The right choice depends on your team's Kubernetes experience.

### Amazon ECS with Fargate (Recommended starting point)

**Fargate** is a serverless compute engine for containers — AWS manages the underlying EC2 instances entirely. You define a **Task Definition** (the equivalent of a Kubernetes Pod spec) and a **Service** (the equivalent of a Deployment).

```hcl
# Terraform: ECS Fargate service for service-orders
resource "aws_ecs_task_definition" "service_orders" {
  family                   = "service-orders"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([{
    name      = "service-orders"
    image     = "${aws_ecr_repository.service_orders.repository_url}:latest"
    portMappings = [{ containerPort = 5002 }]
    environment = [
      { name = "DATABASE_URL", value = "postgresql://..." }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"  = "/ecs/service-orders"
        "awslogs-region" = "us-east-1"
      }
    }
  }])
}

resource "aws_ecs_service" "service_orders" {
  name            = "service-orders"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_orders.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }
}
```

### Auto Scaling ECS Services

Each service gets its own Application Auto Scaling policy — identical in intent to the Kubernetes `HorizontalPodAutoscaler`:

```hcl
resource "aws_appautoscaling_target" "service_orders" {
  max_capacity       = 20
  min_capacity       = 2
  resource_id        = "service/my-cluster/service-orders"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "service_orders_cpu" {
  name               = "orders-cpu-scaling"
  resource_id        = aws_appautoscaling_target.service_orders.resource_id
  scalable_dimension = aws_appautoscaling_target.service_orders.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_orders.service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

### Amazon EKS (When to choose it)

Use **EKS** when:
- Your team already knows Kubernetes and wants to reuse existing Helm charts / manifests from the [base architecture](./software-architecture.md)
- You need advanced scheduling (GPU nodes, spot instance pools, node affinity)
- You're adopting **GitOps** with ArgoCD or Flux

EKS is more powerful but adds complexity. **Start with ECS Fargate and migrate to EKS** only when Kubernetes-specific features are required.

---

## 6. 🗄️ Data Layer: AWS Managed Databases

### Amazon RDS — PostgreSQL

Replaces your `postgres:16-alpine` container with a fully managed, Multi-AZ PostgreSQL instance.

```hcl
resource "aws_db_instance" "postgres" {
  identifier        = "my-app-postgres"
  engine            = "postgres"
  engine_version    = "16.2"
  instance_class    = "db.t3.medium"
  allocated_storage = 50
  storage_encrypted = true

  db_name  = "app_db"
  username = "app_user"
  password = var.db_password   # stored in AWS Secrets Manager

  multi_az               = true     # automatic failover
  backup_retention_period = 7       # 7-day automated backups
  deletion_protection    = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}
```

### Amazon ElastiCache — Redis

Replaces your `redis:7-alpine` container:

```hcl
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "my-app-redis"
  description          = "Redis cache for session and rate limiting"
  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2          # primary + replica
  automatic_failover_enabled = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}
```

### Amazon SQS + SNS — Message Queue

Replaces RabbitMQ for async communication between services:

```
service-orders  →  SNS Topic (order.created)
                       ↓ fan-out
             SQS Queue (notifications)   ←  service-notifications polls
             SQS Queue (analytics)       ←  analytics service polls
             SQS Queue (inventory)       ←  inventory service polls
```

```hcl
resource "aws_sns_topic" "order_created" {
  name = "order-created"
}

resource "aws_sqs_queue" "notifications_queue" {
  name                      = "notifications-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
}

resource "aws_sns_topic_subscription" "order_to_notifications" {
  topic_arn = aws_sns_topic.order_created.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications_queue.arn
}
```

---

## 7. 🔐 Security: IAM, Secrets Manager, VPC

### VPC Design

All private services (ECS tasks, RDS, ElastiCache) run in **private subnets**. Only the API Gateway and CloudFront are public-facing.

```
VPC (10.0.0.0/16)
├── Public Subnets  (10.0.1.0/24, 10.0.2.0/24)
│   └── Application Load Balancer (ALB)
├── Private Subnets (10.0.3.0/24, 10.0.4.0/24)
│   ├── ECS Fargate Tasks (all microservices)
│   ├── Amazon RDS
│   └── Amazon ElastiCache
└── VPC Endpoints
    ├── ECR (pull images without internet)
    ├── S3 (access S3 without internet)
    └── Secrets Manager
```

### AWS Secrets Manager

Replace all `.env` files with **Secrets Manager** references injected at container startup:

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name = "my-app/prod/db-password"
}

# ECS task picks up the secret automatically via IAM role
container_definitions = jsonencode([{
  name = "service-auth"
  secrets = [
    {
      name      = "DATABASE_PASSWORD"
      valueFrom = aws_secretsmanager_secret.db_password.arn
    }
  ]
}])
```

### IAM Roles for ECS Tasks

Each ECS task gets its own IAM role — following least-privilege:

```hcl
resource "aws_iam_role" "service_orders_task_role" {
  name = "service-orders-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy" "service_orders_policy" {
  role = aws_iam_role.service_orders_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage"]
        Resource = aws_sqs_queue.notifications_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}
```

---

## 8. 🚀 CI/CD Pipeline on AWS

The CI/CD pipeline from the [base architecture](./software-architecture.md) (GitHub Actions → Docker → Kubernetes) maps directly to AWS-native tooling.

### Pipeline: GitHub Actions → ECR → ECS

```yaml
# .github/workflows/deploy-service-orders.yml
name: Deploy service-orders

on:
  push:
    branches: [main]
    paths:
      - "packages/service-orders/**"

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 123456789.dkr.ecr.us-east-1.amazonaws.com
  ECR_REPOSITORY: service-orders
  ECS_CLUSTER: my-app-cluster
  ECS_SERVICE: service-orders

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # OIDC token for keyless AWS auth
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC — no long-lived keys)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-deploy
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push Docker image to ECR
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }} \
            -f packages/service-orders/Dockerfile .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }}

      - name: Update ECS service with new image
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --force-new-deployment

      - name: Wait for deployment to stabilize
        run: |
          aws ecs wait services-stable \
            --cluster $ECS_CLUSTER \
            --services $ECS_SERVICE
```

> 💡 **OIDC auth:** The pipeline uses **OpenID Connect** to assume an IAM role — no AWS access keys stored in GitHub secrets. This is the AWS-recommended approach for GitHub Actions.

---

## 9. 📊 Observability: CloudWatch + X-Ray

### Centralized Logging with CloudWatch

Each ECS task ships logs to CloudWatch Logs automatically via the `awslogs` log driver (configured in the task definition). Create log groups per service:

```
/ecs/frontend
/ecs/service-auth
/ecs/service-orders
/ecs/service-notifications
```

### Distributed Tracing with AWS X-Ray

Add X-Ray SDK to each service to get end-to-end trace visibility across the API Gateway → ECS chain:

```javascript
// Node.js service — add to entry point
const AWSXRay = require('aws-xray-sdk-core');
const http = AWSXRay.captureHTTPs(require('http'));

// Traces every incoming request and outgoing HTTP call automatically
```

X-Ray **Service Map** gives you a visual dependency graph of all services, with latency and error rate per edge — identical in value to Jaeger or Instana traces.

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "orders_high_cpu" {
  alarm_name          = "service-orders-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    ClusterName = "my-app-cluster"
    ServiceName = "service-orders"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## 10. 💰 Cost Optimization Tips

| Layer | Cost Optimization |
|---|---|
| **ECS Fargate** | Use Fargate Spot for non-critical services (up to 70% savings) |
| **RDS** | Use `db.t3` or `db.t4g` (Graviton) for lower-traffic services |
| **ElastiCache** | `cache.t3.micro` for dev/staging; reserved instances for prod |
| **CloudFront** | Free tier covers 1TB/month — static frontend costs near zero |
| **API Gateway** | HTTP API is ~70% cheaper than REST API |
| **ECR** | Enable lifecycle policies to delete old image tags automatically |
| **CloudWatch Logs** | Set log retention (e.g., 30 days) — logs stored indefinitely are expensive |
| **SQS** | First 1M requests/month are free; batch message processing reduces cost |

---

## 11. 📋 AWS Service Selection Summary

| Need | AWS Service | Notes |
|---|---|---|
| **Frontend hosting (SSR)** | AWS Amplify | Full Next.js support |
| **Frontend hosting (static)** | CloudFront + S3 | Maximum control, lowest cost |
| **DNS + TLS** | Route 53 + ACM | ACM certs are free |
| **API Gateway** | Amazon API Gateway HTTP API | JWT auth, CORS, rate limiting built-in |
| **User authentication** | Amazon Cognito | JWT issuer for API Gateway authorizer |
| **Container hosting** | ECS Fargate | Start here; move to EKS if needed |
| **Container images** | Amazon ECR | Private registry, IAM-controlled |
| **PostgreSQL** | Amazon RDS (Multi-AZ) | Managed backups, failover |
| **Redis** | Amazon ElastiCache | Cluster mode for high availability |
| **Message queue** | Amazon SQS + SNS | Fan-out patterns, DLQ support |
| **Secrets** | AWS Secrets Manager | Rotated automatically |
| **Config** | AWS SSM Parameter Store | Non-secret config values |
| **IaC** | Terraform or AWS CDK | CDK if you prefer TypeScript |
| **CI/CD** | GitHub Actions + AWS OIDC | Keyless auth to ECR + ECS |
| **Logs** | Amazon CloudWatch Logs | Per-service log groups |
| **Traces** | AWS X-Ray | Service Map across all ECS services |
| **Metrics + Alarms** | Amazon CloudWatch | Trigger auto-scaling and SNS alerts |

---

## Conclusion

Every component from the [base architecture](./software-architecture.md) has a direct, production-ready AWS equivalent. The mapping is clean:

- **Docker containers** → ECS Fargate (or EKS)
- **Container registry** → Amazon ECR
- **API Gateway** → Amazon API Gateway HTTP API
- **Frontend** → AWS Amplify or CloudFront + S3
- **PostgreSQL** → Amazon RDS
- **Redis** → Amazon ElastiCache
- **Message Queue** → Amazon SQS + SNS
- **CI/CD** → GitHub Actions with AWS OIDC → ECR → ECS
- **Logs + Traces** → CloudWatch + X-Ray

The key advantage of running this on AWS: **you stop managing infrastructure and start managing services**. RDS handles failover. ECS Fargate handles cluster nodes. CloudFront handles CDN edge caching. That operational time goes back to product development.

Start with ECS Fargate + RDS + API Gateway — this covers 90% of use cases. Add EKS, MSK, and DocumentDB only when a specific service's requirements demand it.

---

*Tags: `#aws` `#microservices` `#ecs` `#fargate` `#eks` `#apigateway` `#rds` `#elasticache` `#sqs` `#terraform` `#cicd` `#cloudwatch` `#architecture`*
