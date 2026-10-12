# Running AI Agents on Kubernetes

### Reference Architecture, Deployment Guide, Operations, and Team Practices

> **Author:** *Renato Barufi* | **Domain:** AI Platform Architecture | **Reading time:** ~18 min

---

## 1. Executive Summary

Kubernetes can run AI agent services, queue consumers, and isolated task executions, but it does not make an agent safe by itself. An agent combines probabilistic model output with tools that may read data or cause changes. The architecture must constrain what each run can access, execute, spend, and persist.

The recommended starting point is:

1. Expose a small authenticated API that accepts a business task, not arbitrary prompts or Kubernetes objects.
2. Validate and authorize the request before scheduling work.
3. Run bounded agent executions in short-lived Kubernetes Jobs, or use a small worker Deployment consuming a durable queue when throughput requires it.
4. Keep model inference behind a provider-neutral interface. Use an approved external model endpoint or operate a separate inference platform when residency, latency, or economics require it.
5. Treat tool execution as a separate trust boundary. Use explicit tool allowlists, narrowly scoped identities, approval gates, and a sandbox for untrusted code.
6. Persist task state, checkpoints, audit events, and results outside the Pod. Pods and Jobs are replaceable compute, not durable sessions.
7. Begin with recommendation or read-only agents. Add write actions only after evaluation, authorization, approval, and rollback controls are demonstrated.

```text
Clients and internal systems
             |
      Ingress / API Gateway
             |
   Agent API and policy layer -------- Identity provider
             |
      Durable task queue
             |
   Dispatcher / worker controller
             |
      Isolated agent Job -------- Approved model endpoint
             |                    (external or private inference)
             |
     Explicit tool gateway
       |              |
 Read-only APIs   Approved actions
                      |
                Human approval
             |
 Object storage, database, audit log, telemetry
```

This is a reference architecture, not a claim that every agent should be a Job. Choose a Deployment for always-on APIs and queue consumers, a Job for bounded independent runs, and a separate inference serving platform for large model workloads.

---

## 2. Purpose, Scope, and Assumptions

### 2.1 Objectives

| ID | Objective |
|---|---|
| AAK01 | Describe deployment patterns for agent workloads on Kubernetes |
| AAK02 | Separate API, orchestration, inference, state, and tool execution concerns |
| AAK03 | Define a repeatable deployment and release process |
| AAK04 | Identify security, privacy, reliability, scaling, and cost controls |
| AAK05 | Provide practical best practices and deployment-session do/don'ts |
| AAK06 | Define a safe adoption path from read-only assistance to approved actions |

### 2.2 In Scope

- Agents using hosted or self-hosted foundation models
- Synchronous APIs, queue-driven tasks, and bounded agent runs
- Kubernetes Deployments, Jobs, namespaces, policies, and autoscaling
- Tool authorization, secrets, data handling, observability, and evaluation
- CI/CD and GitOps deployment practices

### 2.3 Out of Scope

- Selecting a particular agent framework or model vendor
- A production-ready Helm chart for a specific cluster
- Treating a model response as a trusted policy or executable instruction
- Using Kubernetes as the agent's long-term memory store
- Granting an agent unrestricted cluster administration or shell access

### 2.4 Assumptions to Confirm Before Implementation

The platform and product owners must decide:

- Which users and systems may request runs, and which data each caller may access.
- Whether prompts, outputs, traces, and tool arguments may contain personal, confidential, or regulated data.
- Whether model inference may use an external provider, and which region and retention terms are approved.
- Which tools are permitted, which actions require approval, and who owns the target systems.
- Maximum run duration, model tokens, tool calls, retries, concurrent runs, and spend per tenant.
- Required availability, recovery time, retention periods, and audit evidence.

These are workload requirements, not defaults that Kubernetes can infer.

---

## 3. Workload Patterns

### 3.1 Pattern Selection

| Pattern | Kubernetes resource | Best fit | Main concerns |
|---|---|---|---|
| Agent API | Deployment + Service | Low-latency request validation and task submission | Keep request handling short; do not hold HTTP connections open for long agent loops |
| Queue consumer | Deployment + ServiceAccount | Continuous task consumption and moderate steady throughput | Concurrency, graceful shutdown, visibility timeout, redelivery, and idempotency |
| One task per execution | Job | Bounded, isolated, auditable runs with variable duration | Pod startup overhead, queue-to-Job control, quotas, cleanup, and burst limits |
| Scheduled agent | CronJob | Periodic, bounded analysis or reporting | Concurrency policy, missed schedules, duplicate prevention, and time zones |
| Model inference | Dedicated serving Deployment or managed endpoint | Hosting model weights and inference runtime | GPU scheduling, model distribution, capacity, batching, and independent scaling |

Do not use a new Pod per token or per tool call. The unit of scheduling should normally be a bounded task or a worker process.

### 3.2 Recommended Initial Pattern

For an asynchronous product workflow, begin with an API Deployment, durable queue, and a fixed-size worker Deployment. This is easier to operate than dynamically creating a Job for every request. Use per-run Jobs when stronger isolation, distinct resource profiles, untrusted code, or explicit run-level Kubernetes accounting justifies the extra controller and startup overhead.

For synchronous, short tasks, the API may call an agent runtime directly only when strict request timeouts, cancellation, idempotency, and capacity limits are in place. The API must not become an unbounded agent loop.

### 3.3 Control Plane and Execution Plane

| Plane | Responsibilities | Should not do |
|---|---|---|
| Control plane | Authentication, request validation, policy, queueing, run status, quotas, approvals, cancellation | Execute arbitrary model-generated shell commands |
| Execution plane | Run approved agent code, call permitted model and tool endpoints, emit run events | Create privileged workloads or change its own authorization |
| Inference plane | Serve model requests, manage model versions, batching, accelerator capacity | Share an unrestricted network or identity with agent tools |
| Data plane | Store task records, checkpoints, approved memory, artifacts, and audit evidence | Depend on Pod filesystem for durable state |

The control plane can be application code, a workflow service, or a purpose-built controller. Avoid writing a custom Kubernetes operator until a normal queue and worker design no longer satisfies a verified requirement.

---

## 4. Reference Architecture

```text
                        Users / internal callers
                                   |
                        OIDC, API gateway, WAF
                                   |
                     Agent API (Deployment, stateless)
                    auth | schema | policy | quotas
                                   |
                          Durable task queue
                                   |
                  Dispatcher / workers (Deployment)
                       |                   |
              Run as bounded Job       Run in worker
              when isolation needs it  when throughput wins
                       |                   |
                 Agent runtime and prompt/tool policy
                       |                   |
              +--------+-----------+-------+-----------+
              |                    |                   |
        Model gateway        Tool gateway         State APIs
              |                    |                   |
      Hosted model API      Read-only tools      DB / object store
      or inference pool     Approved actions     audit / checkpoints
                                   |
                           Approval workflow
```

### 4.1 Request Lifecycle

1. Authenticate the caller and derive tenant, role, and allowed data scope from trusted identity claims.
2. Validate the request against a versioned schema. Reject unsupported tools, oversized input, and invalid run options.
3. Create an immutable run record with an idempotency key, policy version, agent version, and request correlation ID.
4. Apply per-caller quotas, data-access policy, and risk classification before placing the task on a durable queue.
5. A worker claims the task with a bounded lease and executes a capped number of model turns and tool calls.
6. Every tool call is checked by the tool gateway. High-impact writes pause for human approval where policy requires it.
7. Persist checkpoints and events as the run progresses. Handle retries as at-least-once delivery unless the selected queue explicitly guarantees otherwise.
8. Store the final result and evidence references, update run status, and emit usage, latency, and outcome metrics.
9. Expire transient data under an explicit retention policy; preserve audit records according to organizational requirements.

### 4.2 Agent Run Contract

Represent each run with a durable record. A practical minimum is:

```text
run_id, tenant_id, requester_id, idempotency_key
agent_name, agent_version, model_id, policy_version
input_reference, status, created_at, started_at, completed_at
deadline, token_budget, tool_call_budget, retry_count
result_reference, audit_reference, failure_code
```

Avoid placing sensitive prompts, full model transcripts, or tool credentials in Kubernetes labels, annotations, event messages, or metric dimensions. Put large or sensitive content in access-controlled storage and reference it by opaque identifier.

---

## 5. Kubernetes Platform Design

### 5.1 Cluster and Namespace Boundaries

- Use a dedicated namespace per environment and, where isolation requirements warrant it, separate namespaces or clusters for trust tiers.
- Apply namespace ResourceQuota and LimitRange so one tenant or burst cannot consume the whole cluster.
- Use Pod Security Admission with the `restricted` profile where compatible; document and review every exception.
- Keep agent workloads off Kubernetes control-plane nodes. Use dedicated node pools for CPU workers and, if needed, accelerator inference.
- Prefer a dedicated cluster for high-risk untrusted code execution. A namespace is not a strong boundary against every kernel or control-plane escape risk.
- Apply NetworkPolicy and confirm that the installed CNI enforces it. Start with default-deny ingress and egress, then permit required DNS, queue, model, telemetry, and tool-gateway destinations.
- Use private cluster endpoints and private image registries where available. Restrict administrative access and audit it.

### 5.2 Resource and Scaling Strategy

- Set CPU and memory requests from measured workload profiles; set limits deliberately and test behavior under throttling and out-of-memory conditions.
- Set per-run deadlines, token and tool-call budgets, queue visibility or lease duration, and maximum concurrency.
- Use HPA for stateless APIs and workers when CPU, memory, or a reliable custom metric represents demand. Queue depth or oldest-message age is often a better worker signal than CPU alone.
- Use KEDA or equivalent event-driven scaling when scaling to queue demand is required. Configure minimum replicas, maximum replicas, cooldown, and scale-to-zero behavior intentionally.
- Use Cluster Autoscaler or the platform equivalent only with realistic pod requests, node limits, and capacity planning.
- For GPU inference, isolate accelerator nodes, set explicit GPU requests, protect model-serving capacity from agent-worker bursts, and measure model load time and utilization.
- Apply backpressure when queue depth, provider throttling, or tool capacity exceeds policy. Do not respond to overload by removing per-run limits.

### 5.3 Scheduling and Disruption

- Use topology spread or pod anti-affinity for highly available API and worker Deployments.
- Configure a PodDisruptionBudget for services that must retain minimum capacity during voluntary disruption; it does not protect against every outage.
- Use graceful shutdown: stop claiming work, finish or checkpoint active runs within the termination grace period, then release leases safely.
- Set `terminationGracePeriodSeconds` consistently with the maximum graceful checkpoint window.
- Set `activeDeadlineSeconds` on bounded Jobs and define retry behavior. Avoid unlimited retries for non-idempotent tools.
- Use `ttlSecondsAfterFinished` for Job cleanup only after results and audit evidence are stored durably.

### 5.4 Persistent and Ephemeral Storage

- Treat container writable layers and `emptyDir` as ephemeral. Use them for temporary files with size limits, not memory, session history, or results.
- Use a database or durable workflow store for run state, leases, approval state, and checkpoints.
- Use object storage for larger artifacts, with encryption, access logging, lifecycle rules, and malware scanning where relevant.
- Do not mount shared writable storage into every agent unless concurrent access, isolation, and cleanup semantics are defined.

---

## 6. Security, Privacy, and Trust Boundaries

### 6.1 Identity and Authorization

- Authenticate humans and services through the organization's identity provider. Do not treat a prompt's claimed user or tenant as identity.
- Enforce authorization in the API and again at the tool/data boundary. A model-generated plan cannot grant access.
- Give each workload a dedicated Kubernetes ServiceAccount. Disable automatic ServiceAccount token mounting when the Pod does not call the Kubernetes API.
- Use workload identity or a secrets integration to grant narrowly scoped access to cloud services. Never bake keys into images or commit them to manifests.
- Separate the identity for image pull, model access, data access, and tool actions where the platform supports it.
- Use short-lived credentials, rotation, and auditable secret access. Do not pass broad cloud credentials to the agent runtime.

### 6.2 Prompt Injection and Tool Safety

Treat user input, retrieved documents, web pages, tickets, code, and tool output as untrusted data. Prompt instructions alone are not an authorization control.

- Expose typed, allowlisted tools through a gateway, not arbitrary network access or a general shell.
- Validate tool arguments against strict schemas and check caller authorization for every operation.
- Separate read and write tools. Require explicit approval for irreversible, financial, external communication, access-control, or production-changing actions.
- Enforce destination allowlists, request timeouts, payload limits, rate limits, and response sanitization at the gateway.
- Make actions idempotent when possible; use operation IDs and record the request, authorization decision, approval, and result.
- Prevent retrieved content from adding tools, changing policy, or expanding data scope.
- For code execution, use a separate sandbox with no production credentials, no host mounts, strict CPU/memory/time limits, and controlled egress. Consider stronger isolation such as microVMs for hostile workloads.

### 6.3 Network and Supply Chain

- Deny public ingress to workers and inference services unless a documented use case requires it.
- Permit outbound connections only to approved DNS, queue, model gateway, tool gateway, and telemetry endpoints.
- Pin images by immutable digest in production. Scan base images and dependencies, sign images, and verify provenance where supported.
- Run as non-root, drop Linux capabilities, disallow privilege escalation, use a read-only root filesystem where practical, and set a seccomp profile.
- Avoid mounting the Docker/container runtime socket, host paths, or Kubernetes credentials into agent Pods.
- Apply admission policies to block privileged containers, host namespaces, mutable production tags, and missing security contexts.

### 6.4 Data Governance

- Classify data before sending it to a model. Minimize, redact, or tokenize fields not required for the task.
- Confirm model provider training, retention, residency, encryption, and subprocessors under the organization's policy.
- Define separate retention for prompts, model outputs, tool arguments, traces, artifacts, and audit metadata.
- Prevent secrets and personal data from appearing in logs, traces, exception messages, and model debugging tools.
- Use tenant-scoped storage authorization, encryption in transit and at rest, and auditable access controls.
- Provide a deletion process that covers derived artifacts and caches without deleting evidence that must legally be retained.

### 6.5 Example Hardened Job

This is a starting point, not a complete production manifest. Replace the image and command with the reviewed runner, and add only the specific environment, volume, and network permissions required. The example assumes credentials are obtained through workload identity or an external secrets integration rather than a literal secret value.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: agent-run-example
  namespace: ai-agents
spec:
  backoffLimit: 1
  activeDeadlineSeconds: 900
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      serviceAccountName: agent-runner
      automountServiceAccountToken: false
      restartPolicy: Never
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: runner
          image: registry.example.com/agents/runner@sha256:REPLACE_WITH_DIGEST
          args: ["run", "--run-id", "$(RUN_ID)"]
          env:
            - name: RUN_ID
              value: "replace-with-opaque-run-id"
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 1Gi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir:
            sizeLimit: 128Mi
```

The `RUN_ID` value above is illustrative; a controller should create a unique Job name and safely provide run metadata. Do not put prompts or credentials in Job names, labels, annotations, or plaintext environment variables. A read-only root filesystem may require an explicit writable temporary directory for the runtime.

---

## 7. Model and Agent Runtime Design

### 7.1 Model Access

| Option | Benefits | Trade-offs |
|---|---|---|
| Managed model provider | Fast start, model choice, provider-operated inference capacity | Data processing terms, network dependency, rate limits, per-token cost, provider availability |
| Self-hosted inference | Greater deployment and data-path control; potential unit economics at sustained utilization | GPU procurement, model serving, capacity management, patching, quality and latency ownership |
| Hybrid | Route by data class, model capability, or availability | More policy, routing, evaluation, and operational complexity |

Put a model gateway or shared client library between agents and providers. It should centralize provider credentials, allowed model IDs, rate limits, timeouts, retries, token accounting, and telemetry. Avoid silent model fallback if the fallback changes data residency, safety behavior, or cost materially.

### 7.2 Agent Runtime Controls

- Version the agent code, prompt templates, tool schemas, policy, and model configuration independently and record all versions per run.
- Bound turns, tokens, tool calls, wall-clock duration, output size, and concurrent tasks.
- Use structured outputs and schema validation for downstream actions. Treat parse failures as failures, not permission to guess.
- Make cancellation observable and cooperative. Stop scheduling new tool calls after cancellation or deadline.
- Keep short-lived conversational context in the run state store. Use explicitly governed retrieval for longer-term memory.
- Add deterministic validation around model outputs before routing, storing, or acting on them.
- Do not allow self-modification of prompts, policies, tool definitions, or deployment configuration in production.

### 7.3 Reliability and Retry Semantics

Assume requests can time out after a downstream operation has succeeded. Use idempotency keys, durable run states, bounded retries with jitter, and deduplication for queue deliveries. Record the outcome of each external action before retrying it.

Use circuit breakers or provider-specific concurrency limits for model and tool endpoints. A model provider timeout should not cause unbounded worker accumulation. Define explicit terminal states such as `succeeded`, `failed`, `cancelled`, `expired`, and `awaiting_approval`.

---

## 8. Observability and Evaluation

### 8.1 Operational Signals

Monitor at least:

| Area | Signals |
|---|---|
| API | Request rate, latency, status codes, auth failures, validation failures |
| Queue | Depth, oldest message age, enqueue/dequeue rate, redelivery, dead-letter count |
| Runs | Active runs, completion and failure rate, duration, cancellation, timeout, retries |
| Model | Requests, latency, tokens, rate limits, provider errors, cost estimates, model/version |
| Tools | Calls by tool and outcome, latency, authorization denials, approvals, external failures |
| Kubernetes | Pod readiness, restarts, throttling, OOM kills, Job duration, pending Pods, node capacity |
| Quality and safety | Evaluation pass rate, schema violations, policy blocks, unsafe-action attempts, user corrections |

Propagate a correlation ID and run ID across API, queue, worker, model gateway, and tool gateway. Keep high-cardinality identifiers in logs and traces, not metric labels. Redact sensitive payloads before telemetry export.

### 8.2 Evaluation Before Release

- Maintain a representative, versioned evaluation set with expected outcomes, policy cases, prompt-injection cases, and failure examples.
- Measure task success, factual or schema correctness, tool selection, unauthorized action rate, latency, and cost.
- Run evaluations when agent code, prompt, tools, model, or policy changes.
- Use shadow or recommendation-only mode before enabling consequential actions.
- Review failures with domain and security owners; do not optimize only for aggregate success rate.
- Keep a rollback path for agent, prompt, model, and tool-policy versions.

### 8.3 Incident Readiness

Provide runbooks for provider outage, queue backlog, unsafe tool behavior, credential exposure, runaway spend, bad release, and suspected data leakage. Each runbook should define how to pause new runs, revoke tool access, drain or quarantine queued work, preserve evidence, notify owners, and restore service.

---

## 9. Deployment Procedure

The procedure below uses generic Kubernetes resources. Use the organization's approved Helm/Kustomize base and GitOps controller if one exists. Direct `kubectl` changes are suitable for a controlled development bootstrap, not as the long-term production source of truth.

### Phase 0: Agree on Guardrails

1. Name the workload owner, security contact, data owner, and on-call team.
2. Approve the data classification, model endpoint, retention, and permitted tools.
3. Set initial per-run and per-tenant limits: deadline, concurrency, token budget, tool-call budget, and cost ceiling.
4. Choose the execution pattern: worker Deployment, bounded Jobs, or a staged combination.
5. Define acceptance tests, rollback conditions, and the kill switch for new runs and tool actions.

### Phase 1: Prepare the Platform

1. Create environment-specific namespaces and apply Pod Security Admission, ResourceQuota, and LimitRange.
2. Configure workload identity or the approved secrets integration. Do not create long-lived credentials for convenience.
3. Apply default-deny NetworkPolicies, then allow only the required DNS, queue, model-gateway, tool-gateway, storage, and telemetry paths.
4. Configure private registry access, image scanning, digest pinning, and admission checks.
5. Confirm node capacity, autoscaling ceilings, storage classes, CNI NetworkPolicy enforcement, and logging/metrics collection.
6. Create a dedicated ServiceAccount with no Kubernetes API permissions unless the workload has a reviewed need.

### Phase 2: Build and Verify the Agent Image

1. Build a minimal image with pinned dependencies and a non-root runtime user.
2. Run unit tests, agent evaluations, dependency and secret scans, image vulnerability scans, and manifest policy checks in CI.
3. Publish an immutable image and record its digest, source revision, and provenance.
4. Verify the container starts with the intended read-only filesystem, dropped capabilities, and resource limits.
5. Promote the same image digest through development, staging, and production; use environment-specific configuration, not rebuilt artifacts.

### Phase 3: Deploy a Restricted Development Slice

Deploy the API and a single worker first, with a non-production model endpoint and read-only tools. A typical GitOps or Kustomize flow is:

```bash
kubectl apply -k deploy/overlays/dev
kubectl -n ai-agents get deployments,pods,services
kubectl -n ai-agents rollout status deployment/agent-api
kubectl -n ai-agents rollout status deployment/agent-worker
```

The paths and resource names are examples; align them with the repository's deployment base. Do not put a real provider key in the command line, shell history, a ConfigMap, or a committed overlay.

Verify:

- A valid request creates one durable run and duplicate submissions are idempotent.
- Invalid or unauthorized requests are rejected before model or tool access.
- The worker cannot reach unapproved destinations or the Kubernetes API.
- The run completes, times out, cancels, retries, and recovers after a worker restart as expected.
- Logs and traces contain correlation identifiers but no unredacted secrets or sensitive prompt content.
- Resource requests, limits, quotas, and maximum concurrency constrain a load test.

### Phase 4: Stage and Production Promotion

1. Deploy to staging with production-like identity, network policy, model routing, and representative data controls.
2. Run security tests, agent evaluations, load tests, provider failure tests, queue redelivery tests, and rollback drills.
3. Enable recommendation-only or shadow behavior and have owners review decisions and cost.
4. Promote by immutable image digest using an approved GitOps change and required review.
5. Start with a small traffic or tenant cohort. Watch quality, denial, latency, capacity, and spend indicators.
6. Enable write tools only after each action has an owner, authorization check, audit record, approval rule, and recovery procedure.
7. Expand rollout gradually. Stop promotion automatically or manually when a defined guardrail is crossed.

### Phase 5: Operate and Improve

1. Review SLOs, cost, queue age, evaluation results, and tool actions on a regular cadence.
2. Patch base images, runtime dependencies, agent frameworks, model clients, and cluster components under a tested release process.
3. Re-run the evaluation set whenever model, prompt, code, tool contract, or policy changes.
4. Test queue recovery, provider failover, cancellation, credential revocation, and disaster recovery.
5. Remove unused tools and permissions; expire temporary artifacts and completed Jobs.

### Release and Rollback Checklist

- [ ] Image is immutable, scanned, signed or provenance-verified per policy, and pinned by digest.
- [ ] Agent, prompt, model, policy, and tool versions are recorded for each run.
- [ ] Evaluations pass the agreed quality and safety thresholds.
- [ ] No unexpected new egress, permissions, mounts, capabilities, or API access is introduced.
- [ ] Limits, quotas, deadlines, queue redelivery, idempotency, and cancellation are tested.
- [ ] Dashboards, alerts, runbooks, owners, and kill-switch access are ready.
- [ ] Rollback or disablement has been rehearsed and does not erase audit evidence.

---

## 10. Deployment Session: Do and Don't

Use this as the agenda for an architecture or release session. The goal is to leave with explicit owners, limits, and evidence, not simply a running Pod.

### Do

- **Do** begin with one concrete workflow and a named business owner.
- **Do** agree which data can reach which model endpoint before testing with realistic data.
- **Do** start with read-only tools and bounded runs; record a baseline for quality, latency, and cost.
- **Do** use a non-production namespace, identity, dataset, and external-system account during early tests.
- **Do** test duplicate requests, queue redelivery, worker termination, provider throttling, cancellation, and timeout behavior.
- **Do** inspect actual egress and authorization denials, not only successful happy-path traces.
- **Do** require structured tool inputs, least-privilege credentials, and an approval path for consequential writes.
- **Do** agree on who can pause new work, revoke tool credentials, and drain or quarantine queued tasks.
- **Do** capture action evidence and decision versions while minimizing sensitive transcript retention.
- **Do** decide measurable promotion and rollback thresholds in advance.

### Don't

- **Don't** give an agent cluster-admin, a privileged Pod, host networking, the container runtime socket, or broad cloud credentials.
- **Don't** expose a general shell, unrestricted browser, or arbitrary URL-fetch tool to production data without a separately reviewed sandbox and egress policy.
- **Don't** let a model's confidence, prompt text, or generated plan act as authorization.
- **Don't** place secrets, full prompts, personal data, or customer identifiers in Pod metadata, metrics, or routine logs.
- **Don't** treat a Kubernetes namespace, a system prompt, or a container boundary as the only security boundary for hostile code.
- **Don't** make an unreviewed write tool available just to make a demo look complete.
- **Don't** automatically retry a non-idempotent action after an ambiguous timeout.
- **Don't** scale workers without provider quotas, tool capacity, queue limits, and budget ceilings.
- **Don't** promote a new model or prompt directly to all users without evaluation and a rollback path.
- **Don't** equate a green Pod status with a safe, correct, or useful agent.

### Session Exit Criteria

Before ending the session, record:

| Decision | Required outcome |
|---|---|
| Workflow and owner | Named workflow, product owner, and operational owner |
| Data and model boundary | Allowed data classes, endpoint, region, retention, and provider conditions |
| Tool permissions | Allowlist, read/write distinction, approver, and credential owner |
| Run limits | Deadline, concurrency, token/tool budgets, retry policy, and spend ceiling |
| Kubernetes boundary | Namespace or cluster, ServiceAccount, quotas, security profile, and egress policy |
| Observability | Run correlation, dashboards, alerts, redaction, and audit location |
| Release gates | Evaluation threshold, staged rollout, stop conditions, and rollback owner |
| Open risks | Risk, accountable owner, mitigation, and due date |

---

## 11. Common Failure Modes

| Failure mode | Why it happens | Mitigation |
|---|---|---|
| Agent Pods can reach too much | Default cluster networking is mistaken for least privilege | Enforced default-deny NetworkPolicy and explicit egress tests |
| Retries repeat external actions | Queue delivery is at-least-once and action result is ambiguous | Idempotency keys, action ledger, bounded retries, and approval for risky work |
| Run state disappears on restart | Conversation and checkpoint state live only in process memory | Durable run store and checkpointed progress |
| Costs spike during an incident | Retries, loops, and autoscaling multiply model calls | Per-run budgets, global concurrency limits, cost alerts, circuit breakers, kill switch |
| Workers scale but throughput does not | Provider or tool quota becomes the bottleneck | Model/tool concurrency controls, queue backpressure, and end-to-end capacity model |
| Sensitive content leaks into telemetry | Default tracing records prompts and tool payloads | Redaction at instrumentation boundary and restricted diagnostic capture |
| Model changes cause behavior drift | Alias or provider deployment changes without controlled evaluation | Pin model versions where possible, record identifiers, evaluate and canary changes |
| Jobs accumulate indefinitely | TTL and lifecycle policies were omitted | TTL cleanup after durable result persistence and namespace quotas |
| Pod is pending indefinitely | GPU, memory, taints, affinity, or quota constraints were not tested | Capacity tests, scheduling dashboards, and bounded autoscaler limits |
| Prompt injection causes an action | Retrieved content is treated as trusted instruction | Tool gateway authorization, untrusted-content handling, and approval gates |

---

## 12. Adoption Roadmap

```text
Stage 1: bounded internal assistant
  read-only data | small cohort | manual review | measured evaluation
          ->
Stage 2: reliable queue-driven service
  durable state | quotas | audit | runbooks | failure and cost controls
          ->
Stage 3: approved actions
  narrow write tools | human approval | idempotency | rollback evidence
          ->
Stage 4: scale and specialization
  workload isolation | event scaling | model routing | optional GPU inference
```

Do not advance a stage because the demo works. Advance when the previous stage meets its quality, security, reliability, and cost criteria under representative load.

---

## 13. Architecture Decisions to Record

| Decision | Recommended starting position |
|---|---|
| Agent execution | Queue-driven worker Deployment; use Jobs where per-run isolation warrants it |
| Inference | Approved managed endpoint initially unless residency, latency, or economics require self-hosting |
| State | Durable external database/workflow store; object storage for artifacts |
| Tool access | Tool gateway with per-operation authorization; no general cluster or shell access |
| Network | Default-deny egress with explicitly approved destinations |
| Identity | Dedicated ServiceAccounts and workload identity; no long-lived embedded credentials |
| Rollout | Read-only first, then shadow/recommendation mode, then narrowly approved actions |
| Scaling | Queue-age/concurrency-aware scaling with provider and spend ceilings |
| Production source of truth | Reviewed GitOps or declarative deployment configuration |

These are defaults to challenge with requirements. Record the chosen option, alternatives, constraints, and review trigger in the architecture decision record.

---

## Conclusion

Kubernetes is a useful execution and scaling platform for AI agents, but the essential design work is the boundary around each run: verified identity, scoped data, constrained tools, bounded compute and model use, durable state, observable decisions, and an operational stop mechanism.

Start with a narrow read-only workflow, durable task handling, and a small evaluation set. Add action-taking capability only when authorization and recovery are stronger than the model's ability to propose an action. Keep inference, agent execution, and privileged tools independently deployable so each can scale and fail without granting the others unnecessary authority.
