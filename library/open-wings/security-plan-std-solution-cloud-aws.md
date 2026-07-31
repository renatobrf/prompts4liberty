# 🔒 Security Plan: Scalable Microservices on AWS

### *Comprehensive security strategy for the cloud-native architecture*

> **Author:** *Renato Barufi* | **Domain:** Cloud Security · AWS | **Reading time:** ~20 min
> **Companion to:** [AWS Cloud Service Guide: Deploying a Scalable Microservices Architecture](./software-architecture-cloud-aws.md)

---

## Introduction

This security plan covers the full threat surface of the microservices architecture described in the AWS cloud guide. It follows the **AWS Well-Architected Framework — Security Pillar** and applies **Defense in Depth**: every layer of the stack has its own security controls, so no single misconfiguration or breach leads to total compromise.

The plan is organized around **seven security domains**:

1. [Identity & Access Management (IAM)](#1-identity--access-management-iam)
2. [Network Security (VPC & Perimeter)](#2-network-security-vpc--perimeter)
3. [Data Protection (At Rest & In Transit)](#3-data-protection-at-rest--in-transit)
4. [Application Security](#4-application-security)
5. [Container & Runtime Security](#5-container--runtime-security)
6. [CI/CD Pipeline Security](#6-cicd-pipeline-security)
7. [Detection, Response & Compliance](#7-detection-response--compliance)

---

## Security Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                       THREAT PERIMETER                               │
│  DDoS (AWS Shield) · Bot Traffic (WAF) · DNS Hijack (Route 53 DNSSEC)│
└───────────────────────────────┬──────────────────────────────────────┘
                                │ HTTPS only (TLS 1.2+)
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│              EDGE LAYER  (Public / Internet-Facing)                  │
│  CloudFront (OAI/OAC) · AWS WAF (OWASP rules) · ACM (TLS certs)     │
│  API Gateway (throttling, JWT authorizer) · Amazon Cognito (IdP)     │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ Private ALB only
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│           WORKLOAD LAYER  (Private Subnets — ECS Fargate)            │
│  Security Groups (deny-by-default) · IAM Task Roles (least-priv)    │
│  Secrets Manager (runtime secrets) · Container image scanning (ECR)  │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ VPC-internal only
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│             DATA LAYER  (Private Subnets — Isolated)                 │
│  RDS (encryption at rest + TLS) · ElastiCache (TLS + auth tokens)   │
│  SQS/SNS (KMS-encrypted) · Secrets Manager (auto-rotation)          │
└──────────────────────────────────────────────────────────────────────┘
        │ All layers
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│           DETECTION & RESPONSE LAYER (Cross-cutting)                 │
│  AWS CloudTrail · GuardDuty · Security Hub · Config · CloudWatch     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. Identity & Access Management (IAM)

### 1.1 Principle of Least Privilege

Every AWS entity (human, service, pipeline) receives **only the permissions required to perform its stated function**. No wildcard (`*`) actions or resources on production roles.

**IAM Role Design Matrix:**

| Actor | Role | Allowed Actions | Denied Explicitly |
|---|---|---|---|
| ECS Task — `service-auth` | `service-auth-task-role` | `secretsmanager:GetSecretValue` (own secret only), `cloudwatch:PutMetricData` | All `iam:*`, `ec2:*`, `s3:DeleteObject` |
| ECS Task — `service-orders` | `service-orders-task-role` | `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage` (own queue), `secretsmanager:GetSecretValue` | Cross-service queue access |
| ECS Task — `service-notifications` | `service-notifications-task-role` | `sqs:ReceiveMessage`, `sqs:DeleteMessage` (notifications queue), `ses:SendEmail` | SQS write to any queue |
| GitHub Actions CI/CD | `github-actions-deploy` | `ecr:GetAuthorizationToken`, `ecr:PushImage`, `ecs:UpdateService`, `ecs:RegisterTaskDefinition` | `iam:*`, `rds:*`, `secretsmanager:*` |
| Developer (human) | `developer-readonly` | `logs:GetLogEvents`, `ecs:DescribeServices`, `cloudwatch:GetMetricData` | All write operations in prod |

**Terraform snippet — deny-all base + targeted allow:**
```hcl
resource "aws_iam_role_policy" "service_auth_policy" {
  role = aws_iam_role.service_auth_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOwnSecret"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:my-app/prod/auth-*"
        ]
      },
      {
        Sid    = "DenyIAMActions"
        Effect = "Deny"
        Action = ["iam:*", "sts:AssumeRole"]
        Resource = "*"
      }
    ]
  })
}
```

### 1.2 Amazon Cognito — User Authentication

- **User Pool** per environment (dev / staging / prod) — never share pools across environments.
- Enable **MFA** (TOTP or SMS) for all admin user groups.
- Configure **password policy**: minimum 12 characters, uppercase + lowercase + numbers + symbols.
- Enable **Advanced Security Mode** (adaptive authentication): blocks sign-ins from compromised credentials, suspicious IP addresses.
- Set short **access token validity** (15–60 minutes); use refresh tokens for session extension.
- Enable **email verification** and block unverified sign-ins.

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "my-app-prod"

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }

  mfa_configuration = "OPTIONAL"   # Enforce for admin groups via group policy

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }
}
```

### 1.3 Service-to-Service Authentication

Internal microservices communicate via private ALB. Authenticate inter-service calls using **short-lived JWT tokens** signed by Cognito, or use **AWS PrivateLink** to restrict access at the network layer without application-level tokens.

---

## 2. Network Security (VPC & Perimeter)

### 2.1 VPC Segmentation

```
VPC (10.0.0.0/16) — us-east-1
├── Public Subnets  (10.0.1.0/24 — AZ-a, 10.0.2.0/24 — AZ-b)
│   ├── Application Load Balancer (public-facing, HTTPS only)
│   └── NAT Gateway (outbound internet for private subnets)
│
├── Private Subnets — App Tier (10.0.3.0/24, 10.0.4.0/24)
│   └── ECS Fargate Tasks (all microservices) — NO public IP
│
├── Private Subnets — Data Tier (10.0.5.0/24, 10.0.6.0/24)
│   ├── Amazon RDS (PostgreSQL Multi-AZ)
│   └── Amazon ElastiCache (Redis cluster)
│
└── VPC Endpoints (no internet egress for AWS API calls)
    ├── com.amazonaws.us-east-1.ecr.api
    ├── com.amazonaws.us-east-1.ecr.dkr
    ├── com.amazonaws.us-east-1.s3
    ├── com.amazonaws.us-east-1.secretsmanager
    ├── com.amazonaws.us-east-1.logs
    └── com.amazonaws.us-east-1.ssm
```

**Data Tier Isolation:** The data subnets have **no route to the internet** and no NAT gateway. The only traffic allowed is from the App Tier subnets on specific database ports.

### 2.2 Security Group Rules (Zero-Trust Between Tiers)

```hcl
# ALB — accepts HTTPS from internet
resource "aws_security_group_rule" "alb_ingress_https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

# ECS — accepts traffic ONLY from ALB security group
resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 5001   # service-specific port
  to_port                  = 5003
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ecs_sg.id
}

# RDS — accepts traffic ONLY from ECS security group
resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

# ElastiCache — accepts traffic ONLY from ECS security group
resource "aws_security_group_rule" "redis_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_sg.id
  security_group_id        = aws_security_group.redis_sg.id
}
```

### 2.3 AWS WAF — Web Application Firewall

Attach an AWS WAF WebACL to both CloudFront and API Gateway.

**Managed Rule Groups to enable:**

| Rule Group | Protects Against |
|---|---|
| `AWSManagedRulesCommonRuleSet` | OWASP Top 10 (SQLi, XSS, path traversal) |
| `AWSManagedRulesKnownBadInputsRuleSet` | Log4Shell, Spring4Shell, SSRF |
| `AWSManagedRulesAmazonIpReputationList` | Known malicious IPs, botnets |
| `AWSManagedRulesBotControlRuleSet` | Scrapers, credential stuffing bots |
| `AWSManagedRulesSQLiRuleSet` | SQL injection patterns |

**Custom rules:**

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "my-app-waf"
  scope = "CLOUDFRONT"   # or REGIONAL for API Gateway

  default_action { allow {} }

  # Rate limiting — 1000 req/5min per IP
  rule {
    name     = "RateLimitPerIP"
    priority = 1
    action   { block {} }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIP"
      sampled_requests_enabled   = true
    }
  }

  # OWASP common rules
  rule {
    name     = "AWSManagedCommon"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedCommon"
      sampled_requests_enabled   = true
    }
  }
}
```

### 2.4 AWS Shield

- **AWS Shield Standard** — automatically enabled for all AWS accounts. Protects against common L3/L4 DDoS attacks.
- **AWS Shield Advanced** — recommended for production. Provides 24/7 DDoS response team (DRT), cost protection for scaling events, and enhanced detection. Enable on: CloudFront, Route 53, ALB.

### 2.5 TLS Policy

- **Minimum TLS version: 1.2** on all endpoints (CloudFront, ALB, API Gateway, RDS, ElastiCache).
- CloudFront security policy: `TLSv1.2_2021` (disables TLS 1.0, 1.1, and weak ciphers).
- ACM certificates: auto-renewed, deployed to CloudFront and ALB.
- RDS: enforce SSL with `rds.force_ssl = 1` parameter group setting.
- ElastiCache: `transit_encryption_enabled = true` (already in the architecture config).

---

## 3. Data Protection (At Rest & In Transit)

### 3.1 Encryption at Rest

| Service | Encryption | Key Management |
|---|---|---|
| **Amazon RDS** | `storage_encrypted = true` (AES-256) | AWS-managed key (`aws/rds`) or CMK |
| **Amazon ElastiCache** | `at_rest_encryption_enabled = true` | AWS-managed key |
| **Amazon SQS** | Server-side encryption enabled | AWS KMS CMK (per queue) |
| **Amazon SNS** | SSE enabled on topics | AWS KMS CMK |
| **Amazon S3** (frontend assets) | SSE-S3 or SSE-KMS | AWS-managed key |
| **Amazon ECR** | Repository encryption enabled | AWS KMS CMK |
| **AWS Secrets Manager** | Always encrypted | AWS KMS CMK |
| **CloudWatch Logs** | Log group encryption | AWS KMS CMK |

**KMS CMK strategy:**
```hcl
resource "aws_kms_key" "app_key" {
  description             = "my-app production data encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # automatic annual rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccount"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowECSTaskDecrypt"
        Effect = "Allow"
        Principal = { AWS = aws_iam_role.service_auth_task_role.arn }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
      }
    ]
  })
}
```

### 3.2 Secrets Management

**Never use environment variables for secrets.** All sensitive values (DB passwords, API keys, JWT signing keys) are stored in **AWS Secrets Manager** with automatic rotation.

```
Rotation schedule:
├── Database passwords         → every 30 days (Lambda rotation function)
├── JWT signing keys           → every 90 days
├── Third-party API keys       → every 90 days
└── Internal service tokens    → every 30 days
```

```hcl
resource "aws_secretsmanager_secret_rotation" "db_password_rotation" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.secret_rotator.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

**SSM Parameter Store** (non-sensitive config):
- Use `SecureString` type for any value that would be embarrassing if leaked.
- Use path hierarchy: `/my-app/{env}/{service}/{key}` (e.g., `/my-app/prod/service-orders/queue-url`).

### 3.3 S3 Bucket Security

```hcl
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront accesses S3 via OAC (Origin Access Control) — not public
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

---

## 4. Application Security

### 4.1 API Gateway Security Controls

| Control | Configuration |
|---|---|
| **Authentication** | Cognito JWT authorizer on all protected routes |
| **Authorization** | Scope-based claims in JWT (`orders:read`, `orders:write`) |
| **Rate Limiting** | 1,000 req/s per API key; burst limit 2,000 |
| **CORS** | Whitelist specific origins only (no wildcard `*` in prod) |
| **Request validation** | Enable request body/parameter validation models |
| **TLS** | Minimum TLS 1.2; disable HTTP |

```yaml
# api-gateway: CORS configuration (restrict to known origins)
cors_configuration:
  allow_origins:
    - "https://www.myapp.com"
    - "https://app.myapp.com"
  allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  allow_headers: ["Authorization", "Content-Type"]
  max_age: 300   # preflight cache (seconds)
  # ❌ Never: allow_origins: ["*"] in production
```

### 4.2 Input Validation & Output Encoding

Apply in each microservice:

- **Validate all input** at the service boundary (not just API Gateway). Use a validation library (e.g., `zod` for Node.js, `pydantic` for Python).
- **Parameterized queries only** — never string-concatenate SQL. Use ORM or prepared statements.
- **Sanitize HTML output** if any service renders HTML. Use a library like `DOMPurify`.
- **Reject oversized payloads** — configure `max-body-size` per service (e.g., 1 MB default, 10 MB for upload endpoints).

### 4.3 Dependency & SBOM Management

- Run `npm audit` / `pip audit` / `go mod audit` in every CI pipeline run — **fail the build on critical CVEs**.
- Enable **Amazon Inspector** for ECR image scanning: automatically scans images on push and on new CVE publication.
- Generate a **Software Bill of Materials (SBOM)** using `cyclonedx-npm` or `syft` in CI — store in S3 per image SHA.
- Pin base image versions (`node:20.14.0-alpine3.20` not `node:lts`); update via Renovate or Dependabot.

### 4.4 HTTP Security Headers

Configure on CloudFront via a **Response Headers Policy**:

```hcl
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "security-headers"

  security_headers_config {
    content_type_options { override = true }   # X-Content-Type-Options: nosniff

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    strict_transport_security {
      access_control_max_age_sec = 63072000   # 2 years
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self';"
      override                = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}
```

---

## 5. Container & Runtime Security

### 5.1 ECR Image Security

```hcl
resource "aws_ecr_repository" "service_orders" {
  name                 = "service-orders"
  image_tag_mutability = "IMMUTABLE"   # ← prevent tag overwrites

  image_scanning_configuration {
    scan_on_push = true   # triggers Amazon Inspector
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.app_key.arn
  }
}

# Lifecycle policy — prevent unbounded image accumulation
resource "aws_ecr_lifecycle_policy" "service_orders" {
  repository = aws_ecr_repository.service_orders.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 production images"
      selection = {
        tagStatus   = "tagged"
        tagPrefixList = ["v"]
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
```

### 5.2 Container Hardening

Apply in every `Dockerfile`:

```dockerfile
# ✅ Use minimal base images
FROM node:20.14.0-alpine3.20 AS builder
# ... build steps ...

FROM node:20.14.0-alpine3.20 AS runtime

# ✅ Run as non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup
USER appuser

# ✅ Drop all capabilities, add only what's needed
# (set in ECS task definition — see below)

# ✅ Read-only filesystem where possible
# (configured in ECS task definition)

WORKDIR /app
COPY --chown=appuser:appgroup --from=builder /app/dist ./dist
EXPOSE 5002

CMD ["node", "dist/server.js"]
```

**ECS Task Definition hardening:**
```hcl
container_definitions = jsonencode([{
  name  = "service-orders"
  image = "${aws_ecr_repository.service_orders.repository_url}:${var.image_tag}"

  # ✅ Non-root user
  user = "1001"

  # ✅ Read-only root filesystem
  readonlyRootFilesystem = true

  # ✅ Drop all Linux capabilities
  linuxParameters = {
    capabilities = {
      drop = ["ALL"]
      add  = []
    }
  }

  # ✅ No privilege escalation
  privileged = false
}])
```

### 5.3 Fargate Runtime Defense

- Enable **Amazon GuardDuty ECS Runtime Monitoring** — detects anomalous container behavior (unexpected network calls, process spawning, privilege escalation attempts) at the Fargate task level.
- **No SSH / exec into production containers** — use ECS Exec only via Session Manager (logged to CloudTrail), never direct SSH.

```hcl
resource "aws_ecs_cluster" "main" {
  name = "my-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Enable ECS Exec (SSM-based, logged — use only for break-glass scenarios)
resource "aws_ecs_service" "service_orders" {
  # ...
  enable_execute_command = true   # Requires task role with ssm:StartSession
}
```

---

## 6. CI/CD Pipeline Security

### 6.1 OIDC Keyless Authentication

The GitHub Actions pipeline must **never use long-lived AWS access keys**. Use OIDC federation as described in the architecture guide — with additional constraints:

```hcl
resource "aws_iam_role" "github_actions_deploy" {
  name = "github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # ✅ Restrict to specific repo and branch — not all repos
          "token.actions.githubusercontent.com:sub" = "repo:my-org/my-repo:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

### 6.2 Pipeline Security Gates

Add mandatory security gates to every CI/CD workflow:

```yaml
# .github/workflows/deploy-service-orders.yml (security-hardened)
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # ✅ Gate 1: Dependency vulnerability audit
      - name: Audit dependencies
        run: npm audit --audit-level=critical

      # ✅ Gate 2: Static Application Security Testing (SAST)
      - name: Run Semgrep SAST
        uses: semgrep/semgrep-action@v1
        with:
          config: p/owasp-top-ten

      # ✅ Gate 3: Secret detection (fail if secrets committed)
      - name: Detect secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}

  build-and-push:
    needs: security-scan
    runs-on: ubuntu-latest
    steps:
      # ... build and push to ECR ...

      # ✅ Gate 4: Container image vulnerability scan
      - name: Scan container image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          format: sarif
          severity: CRITICAL,HIGH
          exit-code: 1   # fail pipeline on critical/high CVEs

  deploy:
    needs: build-and-push
    # ... deploy steps ...
```

### 6.3 Secrets in GitHub Actions

- Store only **non-sensitive references** in GitHub Variables (e.g., AWS account ID, region, cluster name).
- **No AWS credentials** in GitHub Secrets — OIDC eliminates this requirement.
- Any third-party API keys required by CI (e.g., Snyk, SonarCloud tokens) go in GitHub Secrets and are **rotated quarterly**.

### 6.4 Branch Protection & Code Review

- Require **pull request reviews** (minimum 2 approvers) before merge to `main`.
- Enable **required status checks**: all security gates must pass.
- Enable **signed commits** (GPG/SSH) for the `main` branch.
- Prohibit force pushes to `main` and `release/*`.

---

## 7. Detection, Response & Compliance

### 7.1 AWS CloudTrail

Enable CloudTrail in all regions with **multi-region trails** — captures all API calls (management events) and selected data events:

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "my-app-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true  # detect log tampering

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Data events: log S3 object access and Lambda invocations
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::my-app-frontend-prod/"]
    }
  }

  kms_key_id = aws_kms_key.app_key.arn
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn
}
```

### 7.2 Amazon GuardDuty

GuardDuty uses ML and threat intelligence to detect:

- **Unauthorized API calls** from known malicious IPs
- **Crypto-mining** on EC2/ECS
- **Credential exfiltration** (unusual cross-region API calls)
- **Container runtime anomalies** (new process spawning, unexpected network calls)
- **RDS login anomalies** (brute-force attempts, unusual login times)

```hcl
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs         { enable = true }
    kubernetes      { audit_logs { enable = true } }
    malware_protection {
      scan_ec2_instance_with_findings { ebs_volumes { enable = true } }
    }
  }
}
```

**GuardDuty findings → EventBridge → SNS → PagerDuty** (or Slack) for MEDIUM+ severity findings. AUTO-REMEDIATE HIGH/CRITICAL findings where safe (e.g., auto-revoke a compromised IAM key).

### 7.3 AWS Security Hub

Aggregates findings from GuardDuty, Inspector, Config, IAM Access Analyzer, Macie, and Firewall Manager into a single pane of glass.

Enable the following security standards:
- **AWS Foundational Security Best Practices (FSBP)** — 200+ controls
- **CIS AWS Foundations Benchmark v1.4.0**
- **NIST SP 800-53 Rev. 5** (if applicable to your compliance requirements)

```hcl
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "fsbp" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.4.0"
}
```

### 7.4 AWS Config

Use Config rules to continuously audit resource compliance:

| Config Rule | Enforces |
|---|---|
| `s3-bucket-public-access-prohibited` | No public S3 buckets |
| `rds-storage-encrypted` | All RDS instances encrypted |
| `rds-multi-az-support` | RDS in Multi-AZ for prod |
| `ec2-security-group-attached-to-eni` | Security groups in use |
| `iam-no-inline-policy` | Managed policies only |
| `iam-root-access-key-check` | No root access keys |
| `mfa-enabled-for-iam-console-access` | MFA required for all console users |
| `restricted-ssh` | No security group allows SSH from 0.0.0.0/0 |
| `cloudtrail-enabled` | CloudTrail must be on |
| `guardduty-enabled-centralized` | GuardDuty active |

### 7.5 IAM Access Analyzer

Enable IAM Access Analyzer to detect **unintended public or cross-account access** to S3 buckets, IAM roles, KMS keys, SQS queues, and Lambda functions.

```hcl
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "my-app-access-analyzer"
  type          = "ACCOUNT"
}
```

### 7.6 Incident Response Runbooks

**Playbook 1 — Compromised IAM Credentials:**
1. GuardDuty or CloudTrail alert fires → EventBridge rule triggers Lambda.
2. Lambda immediately: `iam:UpdateAccessKey` (disable key) + attach `DenyAll` policy to role.
3. Notify security team via SNS.
4. Forensics: review CloudTrail for actions taken with the compromised key.
5. Rotate secret, review blast radius, patch root cause.

**Playbook 2 — Container Anomaly (GuardDuty ECS finding):**
1. GuardDuty runtime finding → EventBridge → Lambda.
2. Lambda: stop the specific ECS task (`ecs:StopTask`), preserve logs.
3. ECS Service spawns replacement task from known-good image.
4. Alert on-call team with task ARN, finding details, and log group link.

**Playbook 3 — Public S3 Bucket Detected:**
1. Config rule violation → SNS notification.
2. Auto-remediation: Config remediation action calls `s3:PutPublicAccessBlock`.
3. Notify security team; require post-incident review.

### 7.7 Security Monitoring Dashboards

Create CloudWatch dashboards tracking:

| Metric | Alarm Threshold |
|---|---|
| WAF blocked requests rate | > 500/min → alert |
| API Gateway 4xx error rate | > 5% → alert |
| API Gateway 5xx error rate | > 1% → alert |
| GuardDuty HIGH/CRITICAL findings | Any → page on-call |
| Failed Cognito sign-in attempts | > 50/min per IP → alert + WAF block |
| Secrets Manager access outside business hours | Any → alert |
| RDS failed login attempts | > 10/min → alert |

---

## 8. Security Checklist (Pre-Production)

Use this checklist before each production deployment:

### Identity & Access
- [ ] All IAM roles follow least-privilege; no `*` actions in prod
- [ ] Root account has no access keys; MFA enabled
- [ ] All IAM users with console access have MFA
- [ ] GitHub Actions uses OIDC (no long-lived access keys)
- [ ] Cognito MFA enabled for admin groups
- [ ] Cognito Advanced Security Mode set to `ENFORCED`

### Network
- [ ] All ECS tasks run in private subnets with no public IP
- [ ] Data tier subnets have no internet route
- [ ] Security groups follow deny-by-default; only required ports open
- [ ] WAF WebACL attached to CloudFront and API Gateway
- [ ] VPC endpoints configured for ECR, S3, Secrets Manager, SSM, CloudWatch Logs
- [ ] TLS 1.2+ enforced everywhere; HTTP disabled

### Data Protection
- [ ] All RDS instances: `storage_encrypted = true`, `multi_az = true`
- [ ] All ElastiCache: `at_rest_encryption_enabled = true`, `transit_encryption_enabled = true`
- [ ] All SQS queues encrypted with KMS CMK
- [ ] All S3 buckets block public access; frontend accessed via CloudFront OAC only
- [ ] Secrets Manager rotation configured for all credentials
- [ ] No secrets in environment variables or application code

### Application
- [ ] CORS configured with specific origins (no `*` in prod)
- [ ] API Gateway request validation enabled
- [ ] HTTP security headers deployed via CloudFront response headers policy
- [ ] Input validation in every microservice
- [ ] Parameterized queries only — no string-concatenated SQL

### Container
- [ ] All images: `image_tag_mutability = "IMMUTABLE"`
- [ ] ECR scan-on-push enabled; no unresolved CRITICAL CVEs in deployed images
- [ ] All containers run as non-root user
- [ ] `readonlyRootFilesystem = true` in task definitions
- [ ] All Linux capabilities dropped

### CI/CD
- [ ] Dependency audit in CI (fail on CRITICAL)
- [ ] SAST scan (Semgrep) in CI
- [ ] Secret detection (TruffleHog) in CI
- [ ] Container image Trivy scan in CI (fail on CRITICAL/HIGH)
- [ ] Branch protection: 2 reviewers required, status checks mandatory, signed commits

### Detection & Response
- [ ] CloudTrail enabled (multi-region, log validation on, encrypted)
- [ ] GuardDuty enabled with S3, Kubernetes, and malware protection datasources
- [ ] Security Hub enabled with FSBP and CIS standards
- [ ] AWS Config with critical rules deployed
- [ ] IAM Access Analyzer enabled
- [ ] GuardDuty alerts wired to on-call notification channel
- [ ] Incident response runbooks documented and tested

---

## 9. Compliance Considerations

| Standard | Key Controls Covered by This Plan |
|---|---|
| **SOC 2 Type II** | Encryption at rest & in transit, access control, audit logging (CloudTrail), incident response |
| **GDPR** | Data encryption, secrets management, access control, right to erasure (RDS + DocumentDB), audit trails |
| **PCI DSS** | Network segmentation (VPC tiers), WAF, TLS, MFA, vulnerability scanning (Inspector), logging |
| **ISO 27001** | IAM controls, risk management (Security Hub), asset inventory (Config), business continuity (Multi-AZ RDS) |
| **HIPAA** (if applicable) | Encryption, audit controls, access management, BAA with AWS required |

> ⚠️ This plan establishes the **technical controls**. Compliance certification also requires organizational policies, staff training, and third-party audits — outside the scope of this document.

---

## Conclusion

This security plan implements **Defense in Depth** across all seven security domains. No single control is a silver bullet; the strength comes from the combination:

- **Perimeter defense** — WAF, Shield, TLS everywhere, API Gateway throttling
- **Identity controls** — least-privilege IAM, OIDC for CI/CD, Cognito with MFA
- **Network isolation** — private subnets, deny-by-default security groups, VPC endpoints
- **Data protection** — KMS encryption at rest, TLS in transit, Secrets Manager with rotation
- **Runtime hardening** — non-root containers, immutable images, Inspector scanning
- **Continuous detection** — GuardDuty, Security Hub, Config, CloudTrail
- **Fast response** — automated remediation runbooks, on-call alerting

Start with the **Pre-Production Checklist** (Section 8) and treat every item as a hard requirement before going live. Add Security Hub FSBP findings as a living backlog — aim for 90%+ compliance score and review monthly.

---

*Tags: `#security` `#aws` `#microservices` `#iam` `#waf` `#vpc` `#guardduty` `#compliance` `#devsecops` `#cloudtrail` `#securityhub`*
