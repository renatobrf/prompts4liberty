# 🏗️ Software Architecture Model: Scalable Microservices with Frontend + Backend

### *Mono-repo vs. Multi-repo, Docker, and Deployment Strategy for Modern Applications*

> **Author:** *Renato Barufi* | **Domain:** Solution Architecture | **Reading time:** ~15 min

---

## Introduction

When designing a scalable solution based on **microservices**, one of the first architectural questions you'll face is deceptively simple:

> *"Should all of this live in one project, or should I split it into multiple repositories?"*

This question has no universal answer — but it has a **well-reasoned one** based on your team size, deployment needs, and how independently each piece evolves. This post walks through both approaches, shows you when to choose each, and delivers a concrete architecture model for a system where a frontend consumes backend microservices — with full support for **independent Docker containers and deployments**.

---

## 1. 📐 The Solution at a Glance

The system we're designing has these characteristics:

- A **frontend** (React / Next.js) that users interact with directly
- One or more **backend microservices** (Node.js, Go, Python) that the frontend consumes via REST or GraphQL
- **Independent scalability** — each service can be scaled, deployed, and updated on its own
- **Multiple Docker containers** — each component runs in its own container
- A **CI/CD pipeline** that deploys each piece independently

```
┌──────────────────────────────────────────────────────────────┐
│                        CLIENT BROWSER                        │
└────────────────────────────┬─────────────────────────────────┘
                             │ HTTPS
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    FRONTEND (Next.js / React)                │
│                    Docker container: frontend                │
└────────────────────────────┬─────────────────────────────────┘
                             │ REST / GraphQL
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                      API GATEWAY / BFF                       │
│               (Node.js / Kong / AWS API Gateway)             │
│                    Docker container: gateway                 │
└───────────┬─────────────────┬──────────────┬─────────────────┘
            │                 │              │
            ▼                 ▼              ▼
┌─────────────────┐ ┌──────────────────┐ ┌─────────────────────┐
│  Service A      │ │  Service B       │ │  Service C          │
│  (Auth / Users) │ │  (Orders / Core) │ │  (Notifications)    │
│  Node.js        │ │  Go              │ │  Python / FastAPI   │
│  Container: svc-a│ │  Container: svc-b│ │  Container: svc-c   │
└────────┬────────┘ └────────┬─────────┘ └──────────┬──────────┘
         │                   │                       │
         └───────────────────┼───────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                        DATA LAYER                            │
│  PostgreSQL · Redis · MongoDB · Message Queue (RabbitMQ)     │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. 🗂️ Mono-repo vs. Multi-repo: The Core Decision

This is the question most teams wrestle with. Both are valid — but they optimize for different things.

### Option A — Mono-repo (Everything in One Project)

A **mono-repo** keeps the frontend, backend services, shared libraries, Docker configs, and CI/CD definitions in **a single Git repository**.

```
my-app/                          ← single repository
├── packages/
│   ├── frontend/                ← Next.js app
│   ├── api-gateway/             ← BFF / API Gateway
│   ├── service-auth/            ← Auth microservice
│   ├── service-orders/          ← Orders microservice
│   ├── service-notifications/   ← Notifications microservice
│   └── shared/                  ← shared types, utils, contracts
├── infra/
│   ├── docker/                  ← Dockerfiles per service
│   ├── k8s/                     ← Kubernetes manifests
│   └── terraform/               ← infra as code
├── docker-compose.yml           ← local dev: all services at once
└── .github/workflows/           ← CI/CD pipelines
```

**✅ Advantages:**
- Atomic commits across services — change a shared type and update all consumers in one PR.
- A single place to enforce code standards, linting, and dependency management.
- Easier to onboard new developers: clone one repo, run one command.
- Shared packages (types, validation schemas, API contracts) are consumed locally — no versioning pain.
- Local development with `docker-compose up` spins the entire system.

**⚠️ Trade-offs:**
- Requires tooling to avoid building and deploying *everything* on every commit (see below).
- Can become hard to navigate at scale with 20+ services.
- CI pipelines must be smarter — running only affected service pipelines (tools like **Nx**, **Turborepo**, or **Bazel** solve this).

**Best fit for:**
- Teams of 1–15 engineers working across multiple services
- Early-stage products where the codebase is still evolving rapidly
- Solutions where services share a significant amount of code (types, auth logic, validation)

---

### Option B — Multi-repo (One Repo per Service)

A **multi-repo** splits every service into its own Git repository. The frontend lives in `frontend-repo`, each microservice in `service-x-repo`, and shared libraries in `shared-lib-repo`.

```
frontend-repo/          ← Next.js app
api-gateway-repo/       ← API Gateway
service-auth-repo/      ← Auth microservice
service-orders-repo/    ← Orders microservice
shared-contracts-repo/  ← published npm/Go packages (versioned)
infra-repo/             ← Kubernetes, Terraform, Helm charts
```

**✅ Advantages:**
- Perfect isolation — each team owns exactly one repo with no blast radius from other services.
- CI/CD pipelines are simpler per-repo (every push to `main` = one deploy).
- Enforces true independence: services can evolve, be re-written, or decommissioned without touching other repos.
- Access control is fine-grained — give a team access only to their service.

**⚠️ Trade-offs:**
- Cross-cutting changes (e.g., updating a shared type) require coordinated PRs across multiple repos.
- Shared code must be published as versioned packages (npm, Go modules) — adds overhead.
- Harder to keep consistency in coding standards across teams.
- Local development requires either `docker-compose` with image references or a service mesh.

**Best fit for:**
- Teams of 15+ engineers, or multiple distinct product teams
- Mature products where services have **stable contracts** and evolve independently
- Organizations that use **GitOps** (ArgoCD, Flux) and want per-service deployment automation

---

## 3. ⚖️ Recommendation: Start Mono-repo, Split When Needed

> **The right answer for most teams starting a new microservices product: begin with a mono-repo.**

Here's why: the pain of a mono-repo (build tooling, CI complexity) arrives *later*, and can be solved with tooling. The pain of a multi-repo (cross-repo coordination, shared package versioning) arrives *immediately* and is solved only by process discipline.

**Recommended progression:**

```
Phase 1 (0–6 months)   → Mono-repo, docker-compose locally, deploy with simple CI
Phase 2 (6–18 months)  → Add Nx/Turborepo for selective builds, introduce Kubernetes
Phase 3 (18+ months)   → Extract services that need true autonomy into their own repos
```

The key insight: **not all services need to be extracted**. The frontend and API gateway can stay in the mono-repo forever. Only services with dedicated teams and fully independent release cycles are good candidates to split out.

---

## 4. 🐳 Docker Strategy: One Container per Service

Regardless of whether you choose mono-repo or multi-repo, the Docker strategy stays the same: **each service gets its own `Dockerfile` and its own container image**.

### Dockerfile per service (in a mono-repo):

```
infra/docker/
├── Dockerfile.frontend
├── Dockerfile.gateway
├── Dockerfile.service-auth
├── Dockerfile.service-orders
└── Dockerfile.service-notifications
```

### Or co-located with the service (also valid in mono-repo):

```
packages/
├── frontend/
│   └── Dockerfile
├── service-auth/
│   └── Dockerfile
└── service-orders/
    └── Dockerfile
```

### Local Development with `docker-compose`:

```yaml
# docker-compose.yml (root of the mono-repo)
version: "3.9"

services:
  frontend:
    build:
      context: ./packages/frontend
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:4000

  api-gateway:
    build:
      context: ./packages/api-gateway
    ports:
      - "4000:4000"
    depends_on:
      - service-auth
      - service-orders

  service-auth:
    build:
      context: ./packages/service-auth
    ports:
      - "5001:5001"
    environment:
      DATABASE_URL: postgres://user:pass@postgres:5432/auth_db

  service-orders:
    build:
      context: ./packages/service-orders
    ports:
      - "5002:5002"

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - pg_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pg_data:
```

> 💡 **Local dev tip:** Run `docker-compose up` to spin the entire system, or `docker-compose up service-auth` to start just one service. This works identically in a mono-repo or multi-repo (with image references instead of build paths).

---

## 5. 🚀 Deployment Architecture: Independent, Scalable Services

In production, each service is deployed independently. The canonical approach today is **Kubernetes** for orchestration.

### Kubernetes deployment structure:

```
k8s/
├── namespace.yaml
├── frontend/
│   ├── deployment.yaml       ← replicas: 2, image: my-registry/frontend:v1.2
│   ├── service.yaml
│   └── ingress.yaml          ← public-facing, TLS termination
├── api-gateway/
│   ├── deployment.yaml       ← replicas: 3
│   └── service.yaml
├── service-auth/
│   ├── deployment.yaml       ← replicas: 2
│   ├── service.yaml
│   └── hpa.yaml              ← HorizontalPodAutoscaler: scale to 10 on load
├── service-orders/
│   ├── deployment.yaml       ← replicas: 3
│   ├── service.yaml
│   └── hpa.yaml
└── service-notifications/
    ├── deployment.yaml       ← replicas: 1 (lower traffic)
    └── service.yaml
```

### Scaling independently:

Each service defines its own `HorizontalPodAutoscaler`:

```yaml
# k8s/service-orders/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: service-orders-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: service-orders
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
```

This means the `service-orders` container can scale from 2 to 20 replicas based on CPU load — completely independently from the frontend or auth service.

---

## 6. 🔁 CI/CD Pipeline: Deploy Only What Changed

The biggest operational win in a mono-repo is **deploying only the services affected by a given commit**. Tools like **Nx** or **Turborepo** compute a dependency graph and skip builds for unaffected packages.

### Example pipeline (GitHub Actions, mono-repo):

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]

jobs:
  affected:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.nx.outputs.affected }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: npm ci
      - id: nx
        run: echo "affected=$(npx nx show projects --affected --json)" >> $GITHUB_OUTPUT

  build-and-deploy:
    needs: affected
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.affected.outputs.services) }}
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t my-registry/${{ matrix.service }}:${{ github.sha }} -f packages/${{ matrix.service }}/Dockerfile .
      - name: Push to registry
        run: docker push my-registry/${{ matrix.service }}:${{ github.sha }}
      - name: Deploy to Kubernetes
        run: kubectl set image deployment/${{ matrix.service }} ${{ matrix.service }}=my-registry/${{ matrix.service }}:${{ github.sha }}
```

---

## 7. 📋 Decision Matrix: Which Structure for Your Situation?

| Scenario | Recommendation |
|---|---|
| **Solo developer or small team (< 5 engineers)** | Mono-repo — simplicity wins |
| **Startup, MVP, fast iteration** | Mono-repo — maximize speed, defer complexity |
| **Multiple teams, independent release cycles** | Multi-repo or Hybrid (shared libs as packages) |
| **Services with very different tech stacks** | Multi-repo per service |
| **Strong shared domain types / contracts** | Mono-repo or mono-repo with published packages |
| **Regulated environments (SOC 2, HIPAA)** | Multi-repo — fine-grained access control |
| **Kubernetes + GitOps (ArgoCD/Flux)** | Both work — GitOps lives in its own `infra-repo` either way |

---

## 8. ✅ Key Architectural Principles — Summary

1. **One container per service** — regardless of project structure, each deployable unit gets its own Docker image.
2. **Services communicate via stable contracts** — REST, GraphQL, or gRPC — never by importing each other's code directly.
3. **Each service owns its own data store** — shared databases are the #1 cause of tight coupling in microservices.
4. **An API Gateway or BFF decouples the frontend** — the frontend talks to one entry point, not 10 services.
5. **Start mono-repo, split intentionally** — don't optimize for independence before you need it.
6. **CI/CD must support partial deployments** — building and deploying the entire system on every commit destroys the value of microservices.
7. **Infrastructure as code** — Dockerfiles, Kubernetes manifests, and Terraform live alongside the code they describe.

---

## Conclusion

Yes — **it is absolutely possible to have all services in a single project (mono-repo)**, and for most teams it is the recommended starting point. The key is setting up your Docker and CI/CD correctly so that each service can still be **built, tested, and deployed independently**, even when the source code lives together.

The move to multi-repo is a deliberate, gradual choice — made when teams are large enough that code isolation matters more than coordination speed.

The architecture described here gives you:
- 🧩 **Modularity** — each service is an independent deployable unit
- 📦 **Portability** — every service runs in its own Docker container
- 📈 **Scalability** — Kubernetes HPAs scale each service based on real demand
- ⚡ **Velocity** — only changed services are rebuilt and redeployed
- 🔀 **Flexibility** — start mono-repo, extract to multi-repo when the team demands it

---

*Tags: `#microservices` `#architecture` `#docker` `#kubernetes` `#monorepo` `#devops` `#scalability` `#nodejs` `#react` `#cicd`*
