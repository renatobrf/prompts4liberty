# 📋 Budget Plan: AWS Annual Reservation
## Microservices Architecture — Small Project

> **Project:** Scalable Microservices (Frontend + API Gateway + 3 Backend Services)
> **Cloud:** Amazon Web Services — `us-east-1` (N. Virginia)
> **Commitment type:** 1-Year Reserved / Savings Plans — No Upfront
> **Plan date:** 2025
> **References:** [AWS Cloud Service Guide](./software-architecture-cloud-aws.md) · [Cost Estimate](./software-architecture-cloud-aws-cost.md)
> ⚠️ *Validate final prices at [AWS Pricing Calculator](https://calculator.aws/pricing/2/home) before purchase.*

---

## Executive Summary

| | Amount |
|---|---|
| **Annual cost — on-demand (no reservation)** | $2,688 |
| **Annual cost — 1-Year Reserved (this plan)** | **$1,943** |
| **Annual savings from reservations** | **$745** |
| **Monthly cost after reservations active** | **~$162** |
| **Reservation purchase total (no-upfront)** | $0 upfront — billed monthly |
| **Break-even vs. on-demand** | Immediate (month 1 of reservation) |

---

## Part 1 — Reservation Purchase Plan

These are the **three reservation purchases** that unlock the majority of savings. Everything else is pay-as-you-go with no commitment required.

---

### 🛒 Purchase 1 — Compute Savings Plan (ECS Fargate)

| Field | Value |
|---|---|
| **AWS Product** | Compute Savings Plan |
| **Term** | 1 Year |
| **Payment** | No Upfront (monthly billing) |
| **Hourly commitment** | $0.082/hour |
| **Monthly commitment** | ~$60 |
| **Annual commitment** | ~$720 |
| **Covers** | All ECS Fargate tasks in `us-east-1` |
| **On-demand equivalent** | ~$1,140/year |
| **Savings** | ~$420/year (~37%) |
| **Flexibility** | Applies automatically to any Fargate task size or family |
| **When to buy** | Month 3 — after observing real baseline usage |

**What it covers:**

| Service | vCPU | Memory | Replicas |
|---|---|---|---|
| `service-auth` (Node.js) | 0.25 vCPU | 0.5 GB | 2 tasks |
| `service-orders` (Go) | 0.5 vCPU | 1 GB | 2 tasks |
| `service-notifications` (Python) | 0.25 vCPU | 0.5 GB | 1 task |

**How to purchase (AWS Console):**
1. Open **AWS Cost Management** → **Savings Plans**
2. Click **Purchase Savings Plans**
3. Select **Compute Savings Plan**
4. Term: **1 year** | Payment: **No upfront**
5. Set hourly commitment: `$0.082/hr`
6. Review and confirm

**How to purchase (AWS CLI):**
```bash
aws savingsplans create-savings-plan \
  --savings-plan-type "COMPUTE" \
  --term-duration-in-years 1 \
  --payment-option "NO_UPFRONT" \
  --hourly-commitment 0.082 \
  --region us-east-1
```

---

### 🛒 Purchase 2 — RDS Reserved Instance (PostgreSQL)

| Field | Value |
|---|---|
| **AWS Product** | Amazon RDS Reserved DB Instance |
| **Engine** | PostgreSQL |
| **Instance class** | `db.t3.medium` |
| **Deployment** | Multi-AZ |
| **Term** | 1 Year |
| **Payment** | No Upfront |
| **Monthly cost** | ~$44.07 |
| **Annual commitment** | ~$529 |
| **On-demand equivalent** | ~$828/year |
| **Savings** | ~$299/year (~36%) |
| **Region** | `us-east-1` |
| **When to buy** | Month 3 — after confirming DB instance type fits |

> 💡 **Graviton upgrade option:** Switch to `db.t4g.medium` for an additional ~15% discount at the same performance. Annual cost drops to ~$450. Requires PostgreSQL 12.x or higher (already met).

**How to purchase (AWS Console):**
1. Open **Amazon RDS** → **Reserved instances** → **Purchase reserved DB instances**
2. Product description: `PostgreSQL`
3. DB instance class: `db.t3.medium`
4. Multi-AZ: `Yes`
5. Term: `1 year` | Offering type: `No Upfront`
6. Quantity: `1`
7. Confirm purchase

**How to purchase (AWS CLI):**
```bash
# First, find the offering ID for db.t3.medium Multi-AZ PostgreSQL 1yr no-upfront
aws rds describe-reserved-db-instances-offerings \
  --product-description "postgresql" \
  --db-instance-class "db.t3.medium" \
  --multi-az \
  --duration 31536000 \
  --offering-type "No Upfront" \
  --region us-east-1 \
  --query "ReservedDBInstancesOfferings[0].ReservedDBInstancesOfferingId" \
  --output text

# Purchase using the offering ID returned above
aws rds purchase-reserved-db-instances-offering \
  --reserved-db-instances-offering-id <OFFERING_ID_FROM_ABOVE> \
  --reserved-db-instance-id rds-prod-postgres-1yr \
  --db-instance-count 1 \
  --region us-east-1
```

---

### 🛒 Purchase 3 — ElastiCache Reserved Node (Redis)

| Field | Value |
|---|---|
| **AWS Product** | Amazon ElastiCache Reserved Cache Node |
| **Engine** | Redis |
| **Node type** | `cache.t3.micro` |
| **Quantity** | 2 nodes (primary + replica) |
| **Term** | 1 Year |
| **Payment** | No Upfront |
| **Monthly cost** | ~$15.94 × 2 = ~$31.88 |
| **Annual commitment** | ~$383 |
| **On-demand equivalent** | ~$589/year |
| **Savings** | ~$206/year (~35%) |
| **Region** | `us-east-1` |
| **When to buy** | Month 3 |

**How to purchase (AWS Console):**
1. Open **Amazon ElastiCache** → **Reserved cache nodes** → **Purchase reserved cache nodes**
2. Cache node type: `cache.t3.micro`
3. Cache engine: `Redis`
4. Term: `1 Year` | Offering type: `No Upfront`
5. Number of cache nodes: `2`
6. Confirm purchase

**How to purchase (AWS CLI):**
```bash
# Find the offering ID
aws elasticache describe-reserved-cache-nodes-offerings \
  --cache-node-type "cache.t3.micro" \
  --product-description "redis" \
  --duration 31536000 \
  --offering-type "No Upfront" \
  --region us-east-1 \
  --query "ReservedCacheNodesOfferings[0].ReservedCacheNodesOfferingId" \
  --output text

# Purchase 2 nodes
aws elasticache purchase-reserved-cache-nodes-offering \
  --reserved-cache-nodes-offering-id <OFFERING_ID_FROM_ABOVE> \
  --reserved-cache-node-id redis-prod-1yr \
  --cache-node-count 2 \
  --region us-east-1
```

---

## Part 2 — Pay-as-You-Go Services (No Reservation Needed)

These services have no reservation option or are already at minimum cost. They are budgeted as fixed monthly line items:

| Service | Pricing model | Monthly budget | Annual budget |
|---|---|---|---|
| **CloudFront + S3** (frontend CDN) | Per GB + per request | $5 | $60 |
| **Amazon API Gateway** (HTTP API) | Per million calls | $5 | $60 |
| **Amazon ECR** (container registry) | Per GB stored | $1 | $12 |
| **Amazon SQS + SNS** (messaging) | Per million msgs | $2 | $24 |
| **AWS Secrets Manager** | Per secret + API call | $5 | $60 |
| **Amazon Route 53** (DNS) | Per zone + per query | $3 | $36 |
| **AWS Certificate Manager** | — | $0 | $0 |
| **CloudWatch Logs + Alarms** | Per GB ingested | $12 | $144 |
| **AWS X-Ray** (tracing, sampled) | Per million traces | $3 | $36 |
| **Data Transfer (out)** | Per GB | $5 | $60 |
| **Contingency buffer** | — | $10 | $120 |
| **Subtotal** | | **$51** | **$612** |

---

## Part 3 — Complete Annual Budget Table

### Production Environment

| # | Service | Type | Monthly (Reserved) | Annual (Reserved) |
|---|---|---|---|---|
| 1 | CloudFront + S3 | Pay-as-you-go | $5.00 | $60.00 |
| 2 | Amazon API Gateway (HTTP API) | Pay-as-you-go | $5.00 | $60.00 |
| 3 | ECS Fargate — service-auth | Savings Plan | $21.26 | $255.12 |
| 4 | ECS Fargate — service-orders | Savings Plan | $42.65 | $511.80 |
| 5 | ECS Fargate — service-notifications | Savings Plan (partial) + Spot | $10.63 | $127.56 |
| 6 | Amazon RDS PostgreSQL db.t3.medium Multi-AZ | Reserved Instance | $46.37 | $556.44 |
| 7 | Amazon ElastiCache Redis cache.t3.micro × 2 | Reserved Node | $15.94 | $191.28 |
| 8 | Amazon SQS + SNS | Pay-as-you-go | $2.00 | $24.00 |
| 9 | Amazon ECR | Pay-as-you-go | $1.00 | $12.00 |
| 10 | AWS Secrets Manager | Pay-as-you-go | $5.00 | $60.00 |
| 11 | Amazon Route 53 | Pay-as-you-go | $3.00 | $36.00 |
| 12 | AWS Certificate Manager | Free | $0.00 | $0.00 |
| 13 | CloudWatch Logs + Metrics + Alarms | Pay-as-you-go | $12.00 | $144.00 |
| 14 | AWS X-Ray (5% sampling) | Pay-as-you-go | $3.00 | $36.00 |
| 15 | Data Transfer Out (~50 GB/mo) | Pay-as-you-go | $5.00 | $60.00 |
| 16 | Contingency / spikes buffer (5%) | — | $10.00 | $120.00 |
| | **TOTAL — Production** | | **$187.85** | **$2,254.20** |

> Note: Months 1–2 run on-demand (~$224/mo) while sizing is validated. Reservations activate in Month 3, dropping to ~$162/mo. Blended annual: **~$1,943**.

### Optional: Staging + Development Environments

| Environment | Monthly (on-demand, right-sized) | Annual |
|---|---|---|
| **Staging** (half-size, no Multi-AZ) | ~$80 | ~$960 |
| **Development** (minimal, scheduled off-hours) | ~$30 | ~$360 |
| **Subtotal — non-prod** | **~$110** | **~$1,320** |

### Grand Total — All Environments

| Scope | Annual |
|---|---|
| Production (reserved) | ~$1,943 |
| Staging (on-demand) | ~$960 |
| Development (on-demand, scheduled) | ~$360 |
| **Grand Total** | **~$3,263** |

---

## Part 4 — Purchase Timeline

Execute reservations in this order to maximize savings while minimizing risk:

```
WEEK 1 (Project kick-off)
│
├─ ✅ Provision all services on-demand
├─ ✅ Configure AWS Cost Explorer
├─ ✅ Set billing alarm at $250/month
└─ ✅ Tag all resources: Project=my-app, Environment=prod

MONTH 1–2 (Observation period)
│
├─ 📊 Monitor actual Fargate vCPU usage via Cost Explorer
├─ 📊 Verify RDS instance size handles query load
├─ 📊 Confirm Redis memory usage stays < 70%
└─ 📊 Confirm no service needs right-sizing up or down

MONTH 3 (Reservation purchase window) ← ACTION REQUIRED
│
├─ 🛒 Purchase Compute Savings Plan ($0.082/hr, 1-yr, no upfront)
├─ 🛒 Purchase RDS Reserved Instance (db.t3.medium, Multi-AZ, 1-yr, no upfront)
└─ 🛒 Purchase ElastiCache Reserved Nodes (cache.t3.micro × 2, 1-yr, no upfront)

MONTH 3 ONWARD
│
├─ Monthly bill drops from ~$224 to ~$162
├─ Monthly review: Cost Explorer + Trusted Advisor
└─ Quarterly: re-evaluate instance sizes vs. actual usage

MONTH 10–11 (Renewal planning)
│
├─ Review usage growth — upgrade instance sizes if needed
├─ Evaluate 3-year reservations if project is confirmed long-term
│    (3-yr all-upfront saves ~60% vs on-demand)
└─ Renew or adjust Savings Plan commitment
```

---

## Part 5 — AWS Cost Controls Setup

Before any reservation is purchased, configure these guardrails:

### Billing Alarm (required — do on day 1)

```bash
# Create SNS topic for billing alerts
aws sns create-topic --name billing-alerts --region us-east-1

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create billing alarm at $250/month
aws cloudwatch put-metric-alarm \
  --alarm-name "monthly-billing-250" \
  --alarm-description "Alert when monthly AWS bill exceeds $250" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 250 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts \
  --dimensions Name=Currency,Value=USD \
  --region us-east-1
```

### Resource Tagging Policy

Tag every resource at creation time. Required for cost allocation reports:

```bash
# Tag an ECS service
aws ecs tag-resource \
  --resource-arn arn:aws:ecs:us-east-1:ACCOUNT_ID:service/my-cluster/service-orders \
  --tags key=Project,value=my-app key=Environment,value=prod key=Service,value=service-orders

# Tag RDS instance
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:us-east-1:ACCOUNT_ID:db:my-app-postgres \
  --tags Key=Project,Value=my-app Key=Environment,Value=prod Key=Service,Value=database
```

### AWS Budgets — Monthly cap with forecasting

```bash
aws budgets create-budget \
  --account-id ACCOUNT_ID \
  --budget '{
    "BudgetName": "my-app-monthly",
    "BudgetLimit": {"Amount": "250", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostTypes": {"IncludeTax": true, "IncludeSubscription": true}
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL",
                     "Address": "your-email@example.com"}]
  }]'
```

This sends an alert when **forecasted spend is on track to exceed 80% of the $250 budget** — giving you early warning before the bill actually arrives.

### CloudWatch Log Retention (prevents runaway log costs)

```bash
# Set 30-day retention on all service log groups
for group in /ecs/frontend /ecs/service-auth /ecs/service-orders /ecs/service-notifications; do
  aws logs put-retention-policy \
    --log-group-name "$group" \
    --retention-in-days 30 \
    --region us-east-1
done
```

### ECR Lifecycle Policy (prevents image accumulation)

```bash
aws ecr put-lifecycle-policy \
  --repository-name service-orders \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep last 5 tagged images, expire untagged after 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {"type": "expire"}
    },{
      "rulePriority": 2,
      "description": "Keep only last 5 releases",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {"type": "expire"}
    }]
  }' \
  --region us-east-1
```

---

## Part 6 — Monthly Cost Review Checklist

Run this checklist at the start of each month:

```
□ Open AWS Cost Explorer → check actual vs. budget
□ Review Trusted Advisor → idle/underutilized resources
□ Check Savings Plan utilization (target: > 80% coverage)
□ Verify log retention is set on all log groups
□ Review ECR storage — confirm lifecycle policy is removing old images
□ Check RDS storage growth — trigger storage increase if > 80% used
□ Review X-Ray sampling — confirm < 10% trace rate in steady state
□ Check Data Transfer costs — large spike = possible misconfigured service
□ Review Security Hub findings — some findings indicate runaway Lambda/EC2
```

---

## Part 7 — Savings Summary

| Reservation | Annual On-Demand | Annual Reserved | Saved |
|---|---|---|---|
| Compute Savings Plan (Fargate) | $1,140 | $720 | **$420** |
| RDS Reserved Instance | $828 | $529 | **$299** |
| ElastiCache Reserved Nodes | $589 | $383 | **$206** |
| **Total reserved savings** | **$2,557** | **$1,632** | **$925** |

After adding pay-as-you-go services ($612/year) and contingency ($120/year):

| | Total |
|---|---|
| **Annual reserved commitment** | $1,632 |
| **Annual pay-as-you-go services** | $612 |
| **Contingency** | $120 |
| **Full annual budget** | **$2,364** |
| **Blended annual (incl. 2 on-demand months)** | **~$1,943** |

---

## Approval Sign-off

| Role | Name | Decision | Date |
|---|---|---|---|
| **Technical Lead / Architect** | | ☐ Approved / ☐ Rejected | |
| **Engineering Manager** | | ☐ Approved / ☐ Rejected | |
| **Finance / Budget Owner** | | ☐ Approved / ☐ Rejected | |

---

*Document version: 1.0 · Region: us-east-1 · Tags: `#aws` `#budget` `#finops` `#reservation` `#savingsplan` `#microservices`*
