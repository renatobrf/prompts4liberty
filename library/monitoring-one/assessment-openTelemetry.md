# OpenTelemetry Assessment

## Executive Summary

OpenTelemetry (OTel) is an open-source, vendor-neutral observability framework. It provides APIs, SDKs, automatic instrumentation, semantic conventions, context propagation, and the OpenTelemetry Protocol (OTLP) for producing and transporting telemetry.

It is not, by itself, a monitoring dashboard, alerting platform, log search engine, or long-term metrics database. OTel standardizes how applications generate and move observability data to systems that store, query, visualize, and alert on it.

The OpenTelemetry Collector is the component that most closely matches the idea of a generic monitoring agent. It can receive telemetry from many clients, process it centrally, and export it to one or more destinations. A client can send spans, metrics, and logs to a Collector endpoint such as:

```text
Application / agent
        |
        | OTLP over gRPC or HTTP
        v
OpenTelemetry Collector
        |
        +--> Metrics backend / Prometheus-compatible system
        +--> Trace backend / Jaeger, Tempo, commercial APM
        +--> Log backend / Loki, Elasticsearch, SIEM
```

The recommended direction is to instrument applications with OTel APIs and SDKs, send telemetry to a Collector, and keep the final backend replaceable. This gives clients a common telemetry contract without requiring every application to know the details of every monitoring vendor.

---

## 1. Purpose and Scope

This assessment evaluates OpenTelemetry as a shared observability foundation for multiple clients and services.

### 1.1 Objectives

| ID | Objective |
|---|---|
| OT01 | Explain the distinction between OTel instrumentation, SDKs, agents, and the Collector |
| OT02 | Evaluate support for traces, metrics, logs, and related observability data |
| OT03 | Define how clients send telemetry to a shared endpoint |
| OT04 | Identify architectural, operational, security, and cost considerations |
| OT05 | Propose a practical adoption roadmap and proof of concept |

### 1.2 In Scope

- Application instrumentation and automatic instrumentation
- Distributed tracing and context propagation
- Metrics and logs correlation
- OTLP endpoint design
- Collector deployment patterns
- Processing, sampling, routing, and export
- Security, privacy, reliability, and operational governance
- Integration with existing monitoring backends

### 1.3 Out of Scope

- Selecting a single commercial observability vendor
- Building a dashboard or alerting platform
- Replacing infrastructure monitoring tools automatically
- Defining business-specific SLIs without service-owner input
- Treating telemetry as an audit trail or financial system of record

---

## 2. What OpenTelemetry Is

OpenTelemetry is a set of open standards and software components for observability. Its main building blocks are:

| Building block | Responsibility |
|---|---|
| API | Stable interfaces used by application code and instrumentation libraries |
| SDK | Runtime implementation for creating, sampling, batching, and exporting telemetry |
| Automatic instrumentation | Libraries, agents, or middleware that instrument common frameworks and clients |
| Semantic conventions | Common attribute names for HTTP, databases, messaging, cloud resources, and runtimes |
| Context propagation | Carries trace and span context across process and service boundaries |
| OTLP | OpenTelemetry Protocol for transmitting telemetry |
| Collector | Vendor-neutral receive, process, filter, sample, route, and export pipeline |

OTel supports three stable primary signals:

1. **Traces**: A distributed request represented as a trace containing spans.
2. **Metrics**: Measurements such as counters, gauges, and histograms.
3. **Logs**: Timestamped records that can be correlated with trace and span context.

Profiles and other profiling integrations are a separate area of active ecosystem development. They should be evaluated independently instead of being assumed to have the same maturity or portability as traces, metrics, and logs.

### 2.1 OTel Is Not the Backend

OTel does not normally retain telemetry for investigation. A complete observability platform still needs storage and query systems, for example:

| Need | Possible destination |
|---|---|
| Trace storage and exploration | Jaeger, Grafana Tempo, vendor APM |
| Metrics storage and alerting | Prometheus-compatible backend, Grafana Mimir, vendor platform |
| Log search and retention | Loki, Elasticsearch/OpenSearch, SIEM, vendor platform |
| Dashboards | Grafana, vendor UI |
| Alerting and incident workflow | Alertmanager, vendor platform, ITSM/on-call tooling |

The benefit of OTel is that the application-facing contract can remain stable when the destination changes.

---

## 3. Terminology and Architecture

### 3.1 Instrumentation Path

```text
                Application process
       +-------------------------------+
       | Business code                 |
       | OTel API + OTel SDK           |
       | Auto-instrumented libraries   |
       +---------------+---------------+
                       |
                       | spans, metrics, logs
                       v
             Local SDK exporter or agent
                       |
                       | OTLP
                       v
       Collector agent / sidecar / gateway
                       |
             receive -> process -> export
                       |
                       v
            Observability backends
```

### 3.2 Instrumentation Versus Collection

Instrumentation answers: **what happened inside the application?**

Collection answers: **how should telemetry be transported, transformed, governed, and delivered?**

An application SDK may export directly to a backend, but a Collector is usually preferable for a multi-client environment because it centralizes endpoint security, routing, batching, retries, sampling, and vendor-specific exporters.

### 3.3 Trace Concepts

- A **trace** represents one end-to-end operation.
- A **span** represents a timed unit of work within that trace.
- A **parent-child relationship** shows which operation caused another operation.
- A **trace ID** correlates all spans for the operation.
- A **span ID** identifies one operation.
- **Attributes** describe the operation, such as HTTP route, database system, or service name.
- **Events** record notable points inside a span.
- **Links** connect spans that are related but do not have a direct parent-child relationship.

The application should use stable route templates such as `/customers/{customerId}` rather than raw URLs containing high-cardinality identifiers.

### 3.4 Context Propagation

Propagation carries trace context through HTTP, gRPC, messaging, and other supported boundaries. W3C Trace Context is the primary HTTP propagation format used by OTel implementations.

Propagation is what allows a request to be viewed as one distributed trace rather than as unrelated local timings. It does not authenticate a request and must not be treated as a security credential.

---

## 4. Main Features and Capabilities

### 4.1 Automatic and Manual Instrumentation

Most platforms provide automatic instrumentation for common web frameworks, HTTP clients, database drivers, message clients, and runtime components. This is the fastest way to obtain baseline telemetry.

Manual instrumentation remains necessary for business operations and important internal boundaries:

```text
HTTP request span
  +-- database span
  +-- payment authorization span
  +-- event publication span
  +-- business validation event
```

Manual spans should describe meaningful operations, not every function call. Business attributes should be carefully selected and should not contain secrets, payment data, passwords, tokens, or unnecessary personal data.

### 4.2 Metrics

OTel can produce application and runtime metrics such as:

- Request count and error count
- Request duration histograms
- Active requests and queue depth
- Database and dependency latency
- Runtime CPU, memory, garbage collection, and thread metrics
- Business measurements such as orders created, when approved by the domain owner

Metrics are useful for dashboards, alerting, capacity planning, and SLO calculation. Avoid unbounded labels. Customer IDs, request IDs, email addresses, and arbitrary URLs are usually inappropriate metric dimensions.

### 4.3 Logs

OTel can standardize log emission and correlate logs with the active trace and span. A structured log should preferably contain fields such as:

```json
{
  "severity": "ERROR",
  "service.name": "checkout-api",
  "trace_id": "...",
  "span_id": "...",
  "event.name": "payment_authorization_failed",
  "error.type": "TimeoutError"
}
```

OTel does not remove the need for a log retention policy, access control, redaction, or a searchable log backend.

### 4.4 Correlation Across Signals

The combination of `service.name`, resource attributes, trace ID, span ID, timestamps, and semantic conventions makes it possible to move from:

```text
Alert: checkout error rate increased
  -> metric showing the affected route
  -> trace showing the slow dependency
  -> correlated log showing the dependency error
```

This correlation is one of the strongest reasons to adopt OTel consistently across clients.

### 4.5 Collector Processing

A Collector pipeline is assembled from components:

| Component | Purpose |
|---|---|
| Receiver | Accepts OTLP, Prometheus, Jaeger, Zipkin, syslog, or other supported input |
| Processor | Batches, limits memory, enriches resources, transforms, filters, or samples telemetry |
| Exporter | Sends telemetry to OTLP endpoints, Prometheus-compatible systems, logs systems, or vendor backends |
| Connector | Connects one pipeline to another, for example traces to metrics |
| Extension | Supports health checks, authentication, diagnostics, or other Collector services |

A typical production pipeline is:

```text
receivers: otlp
processors: memory_limiter -> resource -> batch -> tail_sampling
exporters: otlp/traces, prometheus/metrics, otlphttp/logs
```

The exact components depend on the chosen Collector distribution and backend. The `contrib` distribution has more receivers and exporters than the core distribution, but it also has a larger upgrade and security surface.

### 4.6 Sampling

Sampling controls telemetry volume and cost.

- **Head sampling** decides near the start of a trace. It is simple and low overhead but may discard an entire trace before its final outcome is known.
- **Tail sampling** waits for more of the trace and can retain errors, slow traces, or traces matching a policy. It requires trace-aware buffering and consistent routing.
- **Always-on sampling** is useful for a small proof of concept but is rarely economical for high-volume production traffic.

Sampling must be designed with the backend and incident workflow. A sampled trace is not proof that an event did or did not occur.

### 4.7 Routing and Multi-Backend Export

The Collector can route telemetry by tenant, environment, namespace, signal, or resource attributes. It can also export one signal to multiple destinations during a migration.

This is useful for:

- Separating development, staging, and production data
- Enforcing tenant isolation
- Sending security-relevant logs to a SIEM
- Migrating from one APM backend to another
- Keeping a low-cost metrics path while retaining selected traces

Routing rules must be explicit and tested. A shared Collector should not become an accidental cross-tenant data path.

---

## 5. Endpoint and Transport Model

### 5.1 OTLP Endpoints

OTLP commonly uses:

| Transport | Typical use |
|---|---|
| OTLP/gRPC | Efficient service-to-service transport; commonly exposed on port `4317` |
| OTLP/HTTP | Firewall- and proxy-friendly transport; commonly exposed on port `4318` |

The actual endpoint, path, authentication, certificate policy, and ports are deployment choices. For OTLP/HTTP, signal-specific paths are commonly used, such as `/v1/traces`, `/v1/metrics`, and `/v1/logs`.

Example client configuration:

```text
OTEL_SERVICE_NAME=checkout-api
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=2026.09.1
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-gateway.example.com:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

For a shared endpoint, use TLS, authentication, quotas, and tenant or environment metadata. Do not expose an unauthenticated Collector receiver to the public internet.

### 5.2 Recommended Deployment Patterns

| Pattern | Description | Best fit |
|---|---|---|
| In-process SDK to gateway | Application exports directly to a centralized Collector | Small deployments and controlled networks |
| Agent per host | Local Collector receives telemetry from processes on the same host | Virtual machines and traditional hosts |
| Sidecar | Collector runs beside each workload | Strong workload isolation; higher resource overhead |
| DaemonSet | One Collector per Kubernetes node | Kubernetes clusters with local collection |
| Gateway Collector | Centralized Collector tier receives from agents and exports | Multi-team, multi-cluster, multi-backend environments |

For Kubernetes, a common pattern is application SDK or auto-instrumentation to a node-local Collector, followed by a gateway tier for centralized processing and export.

### 5.3 Reliability of Telemetry Delivery

Telemetry is normally best effort and must not block the business transaction. Configure:

- Asynchronous batch export
- Bounded queues
- Memory limits and backpressure
- Retry with exponential backoff
- Export timeouts
- Health checks and restart policies
- Disk-backed queues only when their durability and privacy characteristics are understood

When the Collector or backend is unavailable, the application must continue according to the product's availability requirements. Losing observability is undesirable; failing a customer payment because telemetry cannot be exported is usually worse.

---

## 6. Architectural Fit

### 6.1 Strengths

| Area | Assessment |
|---|---|
| Vendor neutrality | Strong; application instrumentation is decoupled from most backend choices |
| Distributed tracing | Strong; mature APIs, SDKs, propagation, and ecosystem support |
| Instrumentation speed | Strong for supported frameworks through auto-instrumentation |
| Signal correlation | Strong when resource conventions and propagation are applied consistently |
| Routing and processing | Strong with a properly operated Collector tier |
| Migration flexibility | Strong; Collector can fan out or switch exporters |
| Ecosystem | Broad language, framework, cloud, and backend support |

### 6.2 Limitations

| Limitation | Consequence |
|---|---|
| Not a complete monitoring product | Backend, dashboards, alerts, and retention still need to be designed |
| Instrumentation quality varies | Automatic instrumentation may miss business context or produce noisy spans |
| Collector operations add responsibility | Teams must manage configuration, upgrades, scaling, and failure modes |
| Semantic conventions evolve | Attribute names and versions require governance |
| Telemetry can be expensive | High-cardinality data and unsampled traces increase storage and network cost |
| Logs are not automatically compliant | Redaction, retention, and access control remain application and platform duties |
| No guaranteed business audit trail | Telemetry may be sampled, delayed, dropped, or transformed |

### 6.3 Fit Score

| Criterion | Score | Comment |
|---|---:|---|
| Standardization across clients | 5/5 | Strong common APIs, protocol, and conventions |
| Distributed request diagnosis | 5/5 | Primary strength of OTel tracing and propagation |
| Backend independence | 5/5 | Good separation from vendor-specific SDKs |
| Operational simplicity | 3/5 | Collector and backend operations are still required |
| Cost control without governance | 2/5 | Uncontrolled telemetry volume can become expensive |
| Compliance by default | 2/5 | Requires explicit privacy, security, and retention controls |

Overall, OTel is highly suitable as a shared observability instrumentation and transport standard. It should be adopted as part of an observability platform, not as a replacement for one.

---

## 7. Security, Privacy, and Compliance

### 7.1 Transport and Access Security

- Require TLS for client-to-Collector and Collector-to-backend traffic.
- Authenticate clients using an appropriate mechanism such as mTLS, bearer tokens, or platform identity.
- Isolate the Collector receiver and management endpoints.
- Apply tenant, environment, and service-level authorization where clients share a gateway.
- Rotate certificates and tokens through the existing secrets-management process.
- Restrict Collector extensions and diagnostic endpoints to trusted networks.

### 7.2 Data Protection

Telemetry frequently contains more data than expected. Define a denylist and review policy for:

- Authorization headers, cookies, session tokens, and API keys
- Passwords and secrets
- Payment card data and financial account data
- National identifiers and personal data
- Full request and response bodies
- Query strings containing credentials or personal data
- User-generated content

Use Collector filtering and transformation as a second line of defense, but do not rely on the Collector as the only protection. Instrumentation libraries and application logging must also avoid emitting sensitive values.

### 7.3 Retention and Residency

Define separate retention policies for traces, metrics, and logs. Trace and log retention may contain personal or confidential data and should be aligned with privacy, contractual, and regulatory requirements. Verify where the selected backend stores data and where Collector traffic crosses network or geographic boundaries.

OTel does not make telemetry immutable. If a legally significant audit record is required, publish that record to a controlled audit system with its own integrity, retention, and access model.

---

## 8. Operational Model

### 8.1 Platform Responsibilities

The platform or observability team should own:

- Collector distributions, images, configuration, and upgrades
- Shared endpoints, certificates, authentication, and quotas
- Backend integrations and export reliability
- Capacity planning, cost monitoring, and retention defaults
- Standard dashboards for Collector health and pipeline loss
- Semantic convention and resource attribute guidance
- Incident response for telemetry pipeline failures

### 8.2 Client Responsibilities

Each client team should own:

- Correct `service.name`, service version, environment, and deployment metadata
- Instrumentation of important business boundaries
- Span naming and attribute quality
- Redaction of sensitive data before emission
- Service-level dashboards, alerts, and SLO definitions
- Telemetry volume and cardinality within the assigned budget
- Testing propagation across synchronous and asynchronous boundaries

### 8.3 Minimum Collector Metrics

Monitor the Collector itself, including:

- Accepted, refused, and dropped spans, metrics, and logs
- Exporter queue size and send failures
- Export latency and retry counts
- Receiver throughput
- Memory usage and batch sizes
- CPU usage and restart count
- Backend throttling and authentication failures

A monitoring system that cannot report its own telemetry loss is operationally incomplete.

---

## 9. Risks and Mitigations

| ID | Risk | Impact | Mitigation |
|---|---|---|---|
| R01 | Sensitive data enters spans or logs | Critical privacy and security exposure | Redaction standards, code review, Collector filters, backend access controls |
| R02 | Unbounded attributes create high cardinality | High storage cost and slow queries | Attribute allowlists, metric label reviews, route templates, budgets |
| R03 | Collector becomes a single point of failure | Telemetry loss or service onboarding blockage | Redundant gateways, health checks, queues, capacity tests |
| R04 | Telemetry export blocks application requests | Product availability degradation | Async export, bounded queues, short timeouts, fail-open behavior |
| R05 | Inconsistent service identity | Broken filtering and misleading dashboards | Required resource attributes and CI validation |
| R06 | Sampling hides important failures | Incomplete incident evidence | Tail-sample errors and slow traces; retain unsampled metrics |
| R07 | Mixed semantic convention versions | Inconsistent queries and dashboards | Versioned guidance and controlled upgrades |
| R08 | Collector configuration becomes ungoverned | Routing leaks, data loss, or fragile deployments | Configuration as code, review, testing, and staged rollout |
| R09 | OTel is mistaken for an audit system | Missing legally required records | Keep authoritative audit events in a dedicated system |
| R10 | Backend lock-in returns through proprietary attributes | Migration effort remains high | Prefer OTel semantic conventions and isolate vendor extensions |

---

## 10. Proposed Target Architecture

```text
                    Client applications
       +----------------+----------------+
       |                |                |
  OTel SDK /      OTel SDK /       OTel auto-
  manual spans   metrics/logs      instrumentation
       |                |                |
       +----------------v----------------+
                Local Collector tier
          batch, limit, enrich, filter
                         |
                         | authenticated OTLP
                         v
                Collector gateway tier
      tenant routing, tail sampling, export
          |              |               |
          v              v               v
       Traces         Metrics           Logs
       backend        backend           SIEM/log backend
```

### 10.1 Recommended Defaults

1. Use OTel APIs and SDKs in supported application languages.
2. Enable automatic instrumentation for baseline coverage.
3. Send telemetry to a Collector instead of coupling applications directly to each vendor backend.
4. Require `service.name`, service version, deployment environment, and cloud or cluster resource metadata.
5. Use W3C trace context across HTTP and messaging boundaries.
6. Keep business spans intentional and low-cardinality.
7. Apply memory limits, batching, retries, timeouts, and bounded queues.
8. Sample traces by policy while retaining errors and high-latency operations.
9. Redact sensitive data before it leaves the application and again at the Collector boundary.
10. Treat metrics as the stable alerting foundation and traces as the diagnostic detail.

---

## 11. Proof of Concept

### 11.1 POC Scope

Use two or three representative services:

- One HTTP API
- One database call
- One asynchronous message producer and consumer
- At least one failure and one slow dependency scenario

### 11.2 POC Acceptance Criteria

| Test | Expected result |
|---|---|
| HTTP request across two services | One trace with parent-child spans |
| Database dependency call | Database span correlated to the request trace |
| Message publish and consume | Context preserved or explicitly linked across the message boundary |
| Application error | Error span and correlated structured log are searchable |
| Collector restart | Application remains available; bounded telemetry loss is measured |
| Backend outage | Queues, retries, and drop behavior are visible and bounded |
| Sensitive attribute test | Deliberately supplied secret does not reach the backend |
| High-cardinality test | Attribute policy prevents unbounded metric labels |
| Sampling test | Errors and slow traces are retained according to policy |
| Version upgrade test | Collector configuration and dashboards remain compatible |

### 11.3 POC Measurements

Record:

- Application CPU and memory overhead
- Collector CPU and memory per throughput unit
- Network volume by signal
- End-to-end telemetry delay
- Drop rate during normal operation and backend outage
- Storage cost estimate by retention period
- Time required to diagnose a deliberately injected failure

---

## 12. Adoption Roadmap

### Phase 0 - Governance and Inventory

- Inventory services, languages, protocols, and existing monitoring agents.
- Select required resource attributes and naming conventions.
- Define prohibited fields and redaction rules.
- Choose initial trace, metric, and log retention targets.

### Phase 1 - Collector Foundation

- Deploy a non-production Collector tier.
- Configure authenticated OTLP/gRPC and OTLP/HTTP receivers.
- Add batching, memory limits, health checks, and a first backend exporter.
- Instrument one representative service.

### Phase 2 - Distributed Trace Pilot

- Instrument an HTTP call chain and one asynchronous workflow.
- Validate propagation, service identity, and error visibility.
- Add dashboards for request rate, errors, duration, and dependency health.

### Phase 3 - Metrics and Logs Correlation

- Add runtime and application metrics.
- Standardize structured logs and trace correlation fields.
- Implement alerting on service-level indicators.

### Phase 4 - Production Rollout

- Add redundancy, quotas, sampling, capacity limits, and backend failover.
- Roll out by domain or service group.
- Measure cost, coverage, telemetry loss, and incident diagnosis time.

### Phase 5 - Continuous Improvement

- Review semantic conventions and instrumentation quality.
- Remove noisy or unused telemetry.
- Revisit sampling and retention based on incident evidence.
- Test backend migration or dual export periodically to preserve portability.

---

## 13. Architecture Decisions to Record

1. Which teams own the shared Collector and backend integrations?
2. Will clients connect directly to a gateway Collector or use a local agent tier?
3. Which authentication method is required for each client class?
4. What is the minimum required resource metadata?
5. What data is forbidden in telemetry, and where is redaction enforced?
6. Which traces are always retained, and which are sampled?
7. What are the maximum telemetry volume and cardinality budgets per service?
8. What is the behavior when the Collector or backend is unavailable?
9. Which signals require geographic or tenant isolation?
10. Which backend capabilities are allowed as vendor-specific extensions?

---

## 14. Conclusion

OpenTelemetry is a strong foundation for a multi-client observability strategy. It can standardize instrumentation and provide a common endpoint through the Collector, while allowing traces, metrics, and logs to be routed to different monitoring tools.

The key architectural correction is that OpenTelemetry is not simply a generic monitoring agent. The client SDKs and instrumentation create telemetry; the Collector receives and processes it; the monitoring backends store and present it. A successful rollout therefore needs all three layers, plus explicit governance for security, privacy, cardinality, sampling, retention, and ownership.

The recommended next step is a focused proof of concept with two services and one asynchronous flow. The POC should measure diagnostic value, resource overhead, failure behavior, data protection, and operating cost before broad client onboarding.

## References

- OpenTelemetry documentation: https://opentelemetry.io/docs/
- OpenTelemetry Protocol: https://opentelemetry.io/docs/specs/otlp/
- OpenTelemetry Collector: https://opentelemetry.io/docs/collector/
- OpenTelemetry semantic conventions: https://opentelemetry.io/docs/concepts/semantic-conventions/
- W3C Trace Context: https://www.w3.org/TR/trace-context/