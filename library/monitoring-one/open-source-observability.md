# Open-Source Observability Solution for Infrastructure and Applications

## Executive Summary

This solution proposes a self-managed observability platform for the beginning stage of a product or platform. It establishes visibility into infrastructure and applications, detects incidents early, and reduces the time required to diagnose failures.

```text
Applications and infrastructure
        |
        | OpenTelemetry, exporters, and probes
        v
Grafana Alloy or OpenTelemetry Collector
        |
        +--> Prometheus       metrics and alert rules
        +--> Loki             logs
        +--> Tempo            distributed traces
        |
        v
Grafana OSS                dashboards, exploration, correlations, alerts
        |
        v
Email, chat, webhook, or incident-management notification
```

The baseline uses free, self-hosted editions. There is no license fee for the core stack, but compute, storage, backup, administration, security, upgrades, and support still have costs. Grafana OSS is different from a Grafana Cloud free plan.

Start with metrics and logs for dependable monitoring, add traces for important application journeys, and introduce profiling or synthetic monitoring after the operating model is stable.

---

## 1. Purpose and Scope

### Objectives

| ID | Objective |
|---|---|
| OBSOSS01 | Monitor hosts, containers, databases, queues, and platform services |
| OBSOSS02 | Detect application errors, latency, availability, and dependency failures |
| OBSOSS03 | Correlate metrics, logs, and traces in one operator experience |
| OBSOSS04 | Avoid a mandatory commercial SaaS dependency |
| OBSOSS05 | Establish a baseline that can grow with traffic and team maturity |
| OBSOSS06 | Define ownership, security, retention, alerting, and operations early |

### In Scope

- Infrastructure and operating-system metrics
- Container and Kubernetes metrics when applicable
- Application metrics, structured logs, and distributed traces
- Database, cache, queue, and HTTP dependency monitoring
- Dashboards, exploration, alert rules, and notifications
- Basic service-level indicators and incident investigation
- Self-hosted deployment, backups, access control, and retention

### Out of Scope

- A legally authoritative audit trail
- A replacement for a SIEM or security operations platform
- Full business intelligence or product analytics
- Guaranteed 24x7 vendor support
- Complete end-user experience monitoring in the first iteration

---

## 2. Recommended Product Stack

| Concern | Product | Role |
|---|---|---|
| Application instrumentation | OpenTelemetry SDKs and auto-instrumentation | Produces metrics, logs, traces, and context |
| Collection | Grafana Alloy or OpenTelemetry Collector | Receives, batches, filters, enriches, and forwards telemetry |
| Metrics | Prometheus plus exporters | Scrapes and stores time-series metrics |
| Host metrics | Node Exporter or Alloy host integration | CPU, memory, disk, network, and filesystem metrics |
| Kubernetes state | kube-state-metrics and node metrics | Workload and cluster state |
| Logs | Loki with Alloy or OTel Collector | Stores and queries structured logs |
| Traces | Grafana Tempo with OTel | Stores distributed traces |
| Visualization | Grafana OSS | Dashboards, Explore, correlation, and alerting |
| Alert notification | Grafana Alerting or Alertmanager | Groups and routes notifications |
| Availability probes | Blackbox Exporter | HTTP, TCP, DNS, and ICMP checks |
| Database metrics | Database-specific exporters | Health, capacity, connections, locks, and latency |
| Optional profiling | Grafana Pyroscope | CPU and memory profiling |

OpenTelemetry keeps application instrumentation independent from storage. Prometheus provides a strong metrics and alerting foundation. Loki and Tempo provide fit-for-purpose log and trace storage. Grafana provides a common operational experience without forcing every signal into one database.

### Alternatives

| Need | Alternative | When to consider it |
|---|---|---|
| Trace storage | Jaeger | Small deployments or existing Jaeger expertise |
| Log storage | OpenSearch | Full-text analytics or existing OpenSearch operations |
| Metrics at scale | Grafana Mimir or Thanos | Multiple Prometheus servers or long retention |
| Collection | OpenTelemetry Collector | Vendor-neutral Collector configuration is preferred |
| Alert routing | Alertmanager | Centralized Prometheus-compatible routing and inhibition |

Review current versions, licenses, integrations, and security advisories before implementation.

---

## 3. Target Architecture

```text
                          Engineers and operators
                                  |
                  Grafana OSS: dashboards, Explore, alerts
                    /             |              \
                   /              |               \
              Prometheus         Loki             Tempo
             metrics store     log store        trace store
                   ^              ^                ^
                   |              |                |
             scrape/export    push/export     OTLP export
                   |              |                |
       +-----------+--------------+----------------+-----------+
       |           Collection and processing layer              |
       | Grafana Alloy or OpenTelemetry Collector               |
       | batch | retry | memory limit | redaction | enrichment  |
       +-----------+--------------+----------------+-----------+
                   ^              ^                ^
                   |              |                |
          Host exporters    Application logs    Application SDKs
          DB exporters      Container logs      auto-instrumentation
          Blackbox probes                       manual spans/metrics
```

### Collection Paths

```text
Application
  -> OTel SDK or automatic instrumentation
  -> local Collector, sidecar, or Alloy agent
  -> authenticated gateway or backend
  -> metrics, logs, and traces
```

Applications should not fail a business operation because the telemetry backend is unavailable. Export asynchronously with bounded queues, short timeouts, and controlled retries.

```text
Host / container / database / endpoint
  -> exporter or probe
  -> Prometheus scrape or Alloy collection
  -> Prometheus
  -> Grafana dashboards and alert rules
```

For Kubernetes, use an Alloy or Collector DaemonSet for local collection, kube-state-metrics for cluster state, and Prometheus for scraping. Add a gateway Collector for multiple clusters, environments, or teams.

---

## 4. Initial Deployment Model

Deploy the first version on one dedicated monitoring VM or in a dedicated Kubernetes namespace:

| Component | Placement | Initial guidance |
|---|---|---|
| Grafana OSS | Monitoring VM or namespace | Persist configuration and dashboards |
| Prometheus | Monitoring VM or namespace | Persistent volume and short retention |
| Loki | Monitoring VM or namespace | Persistent volume and log limits |
| Tempo | Monitoring VM or namespace | Persistent volume and sampled traces |
| Alloy or Collector | Agents on monitored hosts | Optional gateway for shared processing |
| Exporters | Hosts and data services | Restrict endpoints to the monitoring network |
| Notifications | Grafana contact points | Email, chat, or webhook initially |

This first version is not highly available. Add replicas and redundant storage when loss of observability becomes an unacceptable operational risk.

### Scaling Path

```text
Stage 1: one monitoring node and local storage
    -> Stage 2: separate backends and dedicated storage
    -> Stage 3: redundant collectors and Prometheus replicas
    -> Stage 4: Mimir/Thanos, object storage, multi-cluster routing
```

Do not introduce distributed storage before measured volume, retention, or availability requirements justify it.

### Starting Retention

| Signal | Starting retention | Rationale |
|---|---:|---|
| Metrics | 15 to 30 days | Recent trends and incident comparison |
| Logs | 7 to 14 days | Detailed records are high volume |
| Traces | 3 to 7 days | Diagnostic detail with controlled storage |
| Alerts and incidents | Longer than raw telemetry | Preserve operational history |

Measure ingestion volume, query performance, storage growth, and investigation value before extending retention.

---

## 5. Telemetry Standards

### Required Resource Attributes

Every application should provide at least:

```text
service.name
service.version
deployment.environment.name
service.namespace or team
cloud.provider, cloud.region, or cluster identity when applicable
```

Use the same service identity in metrics, logs, traces, dashboards, alerts, and deployment metadata.

### Application Metrics

Collect request count, duration histograms, error count, in-flight requests, queue depth, dependency latency and failures, runtime metrics, worker or consumer processing metrics, and approved business metrics.

Avoid unbounded metric labels. Do not use customer IDs, request IDs, email addresses, raw URLs, or arbitrary exception messages as metric dimensions.

### Structured Logs

Prefer JSON logs with stable fields:

```json
{
  "timestamp": "2026-09-11T12:30:45.123Z",
  "severity": "ERROR",
  "service.name": "checkout-api",
  "service.version": "2026.09.1",
  "event.name": "payment_authorization_failed",
  "trace_id": "...",
  "span_id": "...",
  "error.type": "TimeoutError"
}
```

Never log passwords, tokens, authorization headers, payment data, or unnecessary personal data. Disable request and response bodies by default.

### Distributed Traces

Use OpenTelemetry context propagation across HTTP, gRPC, and messaging boundaries. Instrument stable operations and important business boundaries:

```text
POST /orders
  -> validate order
  -> reserve inventory
  -> authorize payment
  -> publish order-created event
```

Use route templates instead of raw URLs containing identifiers.

### Sampling

- Use metrics for complete volume and error-rate visibility.
- Use head sampling only for small environments or simple policies.
- Prefer tail sampling for errors, slow traces, and selected flows.
- Retain a small baseline sample of successful traces.
- Document what the sampling policy can and cannot prove.

---

## 6. Dashboards and Investigation

### Minimum Dashboards

| Dashboard | Main question |
|---|---|
| Platform overview | Are environments available and within capacity? |
| Host overview | Which hosts have CPU, memory, disk, or network pressure? |
| Kubernetes overview | Which nodes, workloads, namespaces, or volumes are unhealthy? |
| Service overview | What are traffic, errors, latency, saturation, and dependency health? |
| Database overview | Are connections, locks, capacity, or latency abnormal? |
| Collector health | Is telemetry received, queued, retried, or dropped? |
| Logs and traces | Can an operator move from an error to its log and trace? |
| SLO overview | Which user-facing objectives are at risk? |

### Investigation Flow

```text
Alert or user report
  -> service and environment
  -> traffic, error rate, and latency
  -> affected route, dependency, or instance
  -> trace exemplar or trace search
  -> correlated structured log
  -> deployment, configuration, or infrastructure change
  -> mitigation and follow-up action
```

Configure Grafana data links and correlations so operators do not manually copy identifiers between tools.

---

## 7. Alerting Strategy

Alert categories should include availability, user impact, saturation, dependencies, and telemetry pipeline health. Every production alert should have a symptom, service and owner labels, severity, notification route, runbook or investigation link, threshold rationale, and recovery condition.

Initial alert examples:

- HTTP availability below the agreed target for five minutes
- Error rate above the service threshold for five minutes
- P95 latency above the agreed target for ten minutes
- Disk usage above 80 percent, critical at 90 percent
- Persistent volume predicted to fill within the operating window
- Container restart loop or deployment with unavailable replicas
- Database connection pool exhaustion or sustained query failure
- Consumer lag above the agreed processing window
- Prometheus scrape failure or Collector export failure
- Telemetry drop rate above the accepted pipeline budget

Prefer symptom-based alerts. Calibrate thresholds with baseline traffic; generic thresholds create noise.

---

## 8. Security, Privacy, and Reliability

### Platform Security

- Protect Grafana with the organization identity provider when available.
- Use teams, folders, and data-source permissions to separate environments.
- Require TLS for telemetry outside a trusted local network.
- Restrict exporter, Collector, Prometheus, Loki, and Tempo endpoints to the monitoring network.
- Keep secrets, tokens, and certificates in an approved secrets manager.
- Patch images and plugins according to a vulnerability process.
- Back up Grafana configuration, dashboards, alert rules, and backend metadata.

### Data Protection

Apply defense in depth: prevent sensitive values in application logs, filter and redact at the Collector boundary, restrict data-source access, define retention and deletion, and review dashboard exports and incident attachments.

Observability is not an immutable audit system. Important audit events require a separate authoritative system with its own integrity and retention controls.

### Monitor the Monitoring Platform

Monitor scrape and export failures, accepted/refused/dropped telemetry, Collector queues and retries, Prometheus rule health, Loki and Tempo write failures, Grafana availability, alert evaluation, and notification delivery.

Telemetry should be best effort from the application perspective. Bounded asynchronous export is preferred to making customer requests depend on backend availability.

---

## 9. Ownership and Operating Model

| Responsibility | Platform team | Application team | Security team |
|---|---|---|---|
| Grafana, backends, collectors, upgrades | Own | Consult | Consult |
| Service instrumentation and identity | Guide | Own | Consult |
| Dashboards and service alerts | Standards | Own | Consult |
| SLOs and runbooks | Templates | Own with product input | Consult |
| Sensitive-data policy | Enforce controls | Apply in code and logs | Own policy |
| Storage, retention, and capacity | Own defaults | Follow budgets | Consult |
| Incident response | Platform incidents | Service incidents | Security incidents |

Create an observability catalog containing service name, owner, environment, criticality, dependencies, SLOs, dashboards, alerts, and runbook links.

---

## 10. Implementation Roadmap

### Phase 0: Define the Baseline

Identify critical services, hosts, databases, queues, external endpoints, owners, environments, resource attributes, log fields, retention, and sensitive-data rules. Select two or three representative services.

### Phase 1: Infrastructure Monitoring

Deploy Grafana OSS and Prometheus. Install host, database, and platform exporters. Add Blackbox checks, infrastructure dashboards, Collector-health dashboards, and a small set of actionable alerts.

### Phase 2: Application Baseline

Add OpenTelemetry auto-instrumentation. Configure service identity and deployment metadata. Collect request, dependency, runtime, and error telemetry. Introduce structured logs with trace and span correlation, then deploy Loki.

### Phase 3: Distributed Tracing

Deploy Tempo. Add authenticated OTLP ingestion through Alloy or the OTel Collector. Validate HTTP, gRPC, and messaging propagation. Add manual spans for important business boundaries and retain errors and slow traces.

### Phase 4: Service Ownership and SLOs

Define availability and latency SLOs for critical journeys. Add burn-rate or equivalent alerts, service dashboards, runbooks, and incident workflow tests.

### Phase 5: Scale and Improve

Introduce redundant collectors and backends when justified. Add object storage, Mimir or Thanos, profiling, synthetic monitoring, deployment annotations, and topology views as measured needs emerge.

---

## 11. Proof of Concept and Acceptance Criteria

Use one HTTP service, one database dependency, one asynchronous producer and consumer when available, and one monitored host.

| Test | Expected result |
|---|---|
| Successful HTTP request | Metrics, structured log, and trace are correlated |
| Slow database call | Trace identifies dependency and latency contribution |
| Application error | Error alert and correlated error log are available |
| Message publish and consume | Trace context is preserved or an explicit relationship is visible |
| Host disk pressure | Alert identifies host and filesystem |
| Collector restart | Application remains available and telemetry loss is measurable |
| Backend outage | Retry, queue, timeout, and drop behavior remain bounded |
| Sensitive-value test | Deliberately supplied secret does not reach a backend |
| High-cardinality test | Metric labels remain within policy |
| Deployment event | Timeline links the change to affected telemetry |
| Operator drill-down | Alert can be followed from metric to trace to log |

Measure application and Collector overhead, network volume, ingestion delay, storage growth, alert delivery time, and dropped telemetry.

---

## 12. Recommendation

Adopt the self-hosted Grafana OSS stack with OpenTelemetry as the application telemetry standard:

1. Start with Prometheus, Grafana, Alloy or OTel Collector, exporters, and Blackbox checks.
2. Add Loki for structured logs and Tempo for distributed traces in the first application iteration.
3. Keep the first deployment single-node and simple, with explicit backups and short retention.
4. Require consistent service identity, trace propagation, redaction, and ownership before expanding coverage.
5. Use metrics and SLOs for alerting, with traces and logs for diagnosis.
6. Scale to redundant collectors, object storage, Mimir or Thanos, and additional capabilities only when measured requirements demand it.

This provides a credible initial monitoring capability without committing application teams to a commercial APM vendor, while preserving an evolution path toward managed services, a larger open-source deployment, or a commercial backend.