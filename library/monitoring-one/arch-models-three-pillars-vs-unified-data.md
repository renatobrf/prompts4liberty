# Observability Architecture Models: Three Pillars vs. Unified Data

## Executive Summary

Observability is often explained through three pillars: **metrics, logs, and traces**. This model remains useful because each signal has different characteristics, costs, retention needs, and operational uses.

The three-pillar model becomes incomplete when teams need to investigate a distributed problem across services, infrastructure, user journeys, and business outcomes. A **unified observability data model** treats telemetry as related evidence about entities and events. It connects signals through common identity, timestamps, context propagation, resource attributes, semantic conventions, and relationships.

These are not mutually exclusive architectures:

```text
Three pillars = signal production, storage, and operational specialization
Unified model  = correlation, discovery, analysis, and decision-making
```

The recommended architecture is a **hybrid**:

1. Produce metrics, logs, traces, profiles, events, and checks using fit-for-purpose instrumentation.
2. Standardize identity and context across all telemetry.
3. Collect and govern data through a common pipeline such as OpenTelemetry Collector.
4. Store data in specialized backends where their query and retention characteristics are strongest.
5. Expose a unified investigation experience that links related observations.

The unified model should not require every signal to be stored in one database. Unification is primarily a **data contract and relationship model**, not necessarily a single physical repository.

---

## 1. Purpose and Scope

This analysis compares two ways of structuring an observability architecture and describes practical ways to apply observability in software platforms.

### 1.1 Objectives

| ID | Objective |
|---|---|
| OBSM01 | Explain the strengths and limitations of the three-pillar model |
| OBSM02 | Define a unified observability data model |
| OBSM03 | Compare storage, operating, and investigation consequences |
| OBSM04 | Describe practical observability application patterns |
| OBSM05 | Recommend an adoption path compatible with OpenTelemetry |

### 1.2 In Scope

- Metrics, logs, traces, profiles, events, and synthetic checks
- Service, infrastructure, application, dependency, user, and business context
- Data collection, correlation, storage, querying, alerting, and incident response
- SLO-driven and exploratory observability workflows
- Platform governance, cost, privacy, and data quality

### 1.3 Out of Scope

- Selecting one commercial observability vendor
- Defining a single dashboard design for every team
- Treating telemetry as a legally authoritative audit record
- Replacing domain data platforms, SIEMs, or financial systems of record

---

## 2. What Observability Means

Monitoring asks whether a known condition is healthy. Observability asks whether the available evidence is sufficient to explain the internal state of a system from its external outputs.

This distinction is practical rather than semantic:

| Activity | Primary question | Typical result |
|---|---|---|
| Monitoring | Is a known condition outside its expected range? | Alert, dashboard, threshold, SLO burn rate |
| Troubleshooting | What component is failing right now? | Timeline, dependency view, error grouping |
| Observability | What is happening, why is it happening, and what else is affected? | Correlated investigation across signals and entities |

Observability is valuable when the system has unknown failure modes, asynchronous communication, dynamic infrastructure, third-party dependencies, or several teams sharing a transaction path.

### 2.1 The Four Questions

A useful observability capability should help answer:

1. **What changed?** Deployment, configuration, traffic, dependency, schema, or infrastructure change.
2. **What is affected?** Services, endpoints, tenants, regions, users, orders, or business capabilities.
3. **Why is it affected?** Error, saturation, latency, dependency failure, capacity, code path, or data quality problem.
4. **What should happen next?** Mitigate, roll back, scale, repair, communicate, or improve the system.

---

## 3. Model A: The Three Pillars

### 3.1 Signals

| Signal | Basic unit | Best at | Main weakness |
|---|---|---|---|
| Metrics | Numeric measurement over time | Trends, alerting, SLOs, capacity, aggregation | Limited detail about one request or event |
| Logs | Structured or unstructured record | Detailed facts, error messages, discrete events | Expensive to search and easy to make noisy |
| Traces | Timed spans forming a request path | Distributed causality, latency breakdown, dependency analysis | Sampling and instrumentation gaps can hide evidence |

The model is easy to explain and maps naturally to specialized platforms:

```text
                         Observability
                              |
          +-------------------+-------------------+
          |                   |                   |
       Metrics              Logs                Traces
     time series       event records       span relationships
          |                   |                   |
     metrics store       log store        trace store
```

### 3.2 Strengths

- Clear ownership and familiar tooling.
- Each signal can use an appropriate storage engine and retention period.
- Metrics provide a relatively stable and economical alerting layer.
- Logs preserve detailed application and operational context.
- Traces represent causality across synchronous and asynchronous boundaries.
- Teams can adopt one signal at a time.

### 3.3 Limitations

- Teams may operate three disconnected tools and manually copy identifiers between them.
- A log line can use one service name while a trace uses another, making correlation unreliable.
- The model does not naturally represent profiles, deployment changes, topology, or business events.
- Different teams can define the same concept with incompatible names and dimensions.
- Storage boundaries can become investigation boundaries.
- Alerting often detects symptoms without showing the affected customer or business capability.

The three pillars are therefore a useful **emission and backend model**, but an incomplete **investigation model**.

---

## 4. Model B: A Unified Observability Data Model

A unified model organizes evidence around common entities and relationships. Signals remain distinct, but the user can navigate across them using shared dimensions.

### 4.1 Core Entities

```text
Tenant / user / business operation
              |
         trace context
              |
Service -> endpoint -> dependency -> infrastructure resource
   |            |             |                 |
 metrics      spans         logs              profiles
   |            |             |                 |
       deployment / version / configuration change
```

The minimum shared concepts are:

| Concept | Examples | Why it matters |
|---|---|---|
| Entity | Service, host, pod, database, queue, endpoint | Defines what produced or received evidence |
| Resource identity | `service.name`, environment, cluster, region, version | Makes data addressable and groupable |
| Operation | HTTP route, job, consumer, database query class | Defines the work being performed |
| Context | Trace ID, span ID, parent, tenant or request context | Links evidence across boundaries |
| Time | Event time, start/end time, ingestion time | Supports ordering and latency analysis |
| Measurement | Count, duration, size, utilization, error rate | Supports aggregation and alerting |
| Event | Exception, deployment, feature flag change, business event | Explains state transitions and changes |
| Relationship | Calls, publishes, consumes, depends on, affects | Supports topology and causality analysis |
| Classification | Severity, status, outcome, environment, domain | Enables filtering and policy |

### 4.2 Canonical Record Shape

The following is a conceptual shape, not a requirement to serialize every signal identically:

```json
{
  "observed_at": "2026-09-11T12:30:45.123Z",
  "event_type": "span",
  "entity": {
    "service.name": "checkout-api",
    "deployment.environment": "production",
    "service.version": "2026.09.1",
    "cloud.region": "us-east-1"
  },
  "operation": {
    "name": "POST /orders",
    "type": "http.server"
  },
  "context": {
    "trace_id": "...",
    "span_id": "...",
    "parent_span_id": "..."
  },
  "outcome": {
    "status": "error",
    "error.type": "PaymentTimeout"
  },
  "attributes": {
    "http.request.method": "POST",
    "server.address": "orders.example.com"
  },
  "relationships": [
    {"type": "calls", "target": "payment-service"}
  ]
}
```

Metrics, logs, and traces have different native shapes. A metric data point does not need a span ID, and a log does not need to become a span. The important requirement is that common attributes and relationships are available when they are meaningful.

### 4.3 Unified Does Not Mean One Backend

There are three different meanings of “unified”:

| Meaning | Description | Assessment |
|---|---|---|
| Unified collection | One agent or pipeline accepts multiple signals | Usually desirable |
| Unified data contract | Shared identity, context, semantics, and relationships | Strongly recommended |
| Unified storage | All data is copied into one physical platform | Situational and often costly |

The first two forms usually provide most of the architectural benefit. A single backend can simplify discovery, but it may introduce cost, query limitations, migration risk, or poor fit for specialized data types.

---

## 5. Direct Comparison

| Dimension | Three pillars | Unified data model |
|---|---|---|
| Primary abstraction | Signal type | Evidence about entities and relationships |
| Main user workflow | Open the metrics, logs, or traces tool | Start from an entity or symptom and navigate related evidence |
| Storage strategy | Specialized backend per signal | Specialized backends behind a shared query or correlation layer |
| Alerting | Mostly metric and log rules | Metrics plus context from traces, events, topology, and changes |
| Root-cause analysis | Manual correlation using IDs and timestamps | Relationship-aware navigation and common dimensions |
| Onboarding | Add instrumentation for a signal | Add instrumentation plus identity and semantic requirements |
| Cost control | Per-signal quotas and retention | Per-signal controls plus entity, cardinality, and relationship governance |
| Failure mode | Data exists but is disconnected | Bad shared identity can connect data incorrectly or not at all |
| Best fit | Smaller systems and clear operational boundaries | Distributed platforms and cross-team investigations |
| Main risk | Tool fragmentation | Complexity and over-normalization |

### 5.1 Decision Matrix

| Situation | Preferred emphasis |
|---|---|
| Single application with a small team | Three pillars with basic correlation |
| Multiple microservices and asynchronous messaging | Unified identity and trace context |
| Strong SLO and on-call practice | Metrics-first, with unified drill-down |
| High-volume logs and strict retention rules | Specialized log storage with shared metadata |
| Frequent deployment-related incidents | Unified deployment, version, and change events |
| Customer-impact analysis | Unified business context with privacy controls |
| Large multi-tenant platform | Unified contract plus strict tenant isolation |
| Highly regulated audit requirements | Observability plus a separate authoritative audit model |

---

## 6. Reference Architecture

```text
 Applications, platforms, and user-facing clients
   |         |          |           |          |
   |    metrics      logs       traces    profiles/events
   +---------+----------+-----------+----------+
                     |
          OpenTelemetry APIs, SDKs,
          semantic conventions, context
                     |
        Local Collector / agent / sidecar
       batch, redact, enrich, limit, retry
                     |
              Authenticated OTLP
                     |
              Gateway Collector tier
       route, sample, transform, fan out
          |             |              |
          v             v              v
   Metrics backend  Trace backend  Log backend
          |             |              |
          +-------------+--------------+
                        |
         Correlation, topology, query, and
         incident workflow experience
                        |
       SLOs, alerts, investigation, and action
```

### 6.1 Responsibilities by Layer

| Layer | Responsibility |
|---|---|
| Application | Emit meaningful telemetry, preserve context, avoid sensitive data |
| SDK or agent | Batch, sample where appropriate, and export asynchronously |
| Collector | Authenticate, enrich, filter, route, retry, and measure pipeline health |
| Backends | Store and query signal-specific data with appropriate retention |
| Correlation layer | Link entities, changes, signals, and related investigations |
| Incident workflow | Turn evidence into response, ownership, communication, and learning |

The Collector and correlation layer should be separate concerns. A Collector transports and processes telemetry; it does not automatically create a complete unified query experience.

---

## 7. Ways to Apply Observability

Observability should be applied to a workflow and a decision, not only to a technology component. The following application patterns can coexist.

### 7.1 Reactive Incident Diagnosis

**Question:** What is failing now?

```text
Alert or user report
    -> affected SLO or metric
    -> service and operation
    -> trace or dependency map
    -> correlated log and exception
    -> recent deployment or configuration change
    -> mitigation and owner
```

Use metrics for detection and traces, logs, profiles, and change events for diagnosis. The success measure is reduced time to detect and reduced time to restore, not the number of dashboards.

### 7.2 SLO and Error-Budget Management

**Question:** Is the service meeting the reliability promised to users?

Define:

- **SLI:** A measured indicator such as successful requests or latency within a threshold.
- **SLO:** The target for the SLI over a time window.
- **Error budget:** The permitted amount of unreliability in that window.
- **Burn rate:** How quickly the service is consuming that budget.

Use metrics as the authoritative alerting input for SLOs. Use traces and logs to explain which routes, dependencies, regions, or versions are consuming the budget.

### 7.3 Distributed Transaction Analysis

**Question:** Where is time or failure introduced across a user operation?

Instrument the transaction boundary, propagate context across HTTP, RPC, and messaging, and create spans for meaningful dependency calls. Add business-safe attributes such as operation type or order state, rather than raw personal data or unrestricted identifiers.

### 7.4 Infrastructure and Platform Capacity

**Question:** Is the platform approaching saturation or wasting capacity?

Combine host, container, Kubernetes, database, queue, and application metrics with deployment metadata. Use profiles to identify CPU or memory hot spots and traces to show whether platform saturation affects user-facing latency.

### 7.5 Release and Change Observability

**Question:** Did a change cause a behavioral regression?

Emit deployment, configuration, feature-flag, schema, and infrastructure change events using the same service and environment identity as runtime telemetry. Compare error rate, latency, throughput, and dependency behavior before and after the change.

### 7.6 Business and User-Journey Observability

**Question:** Which customer or business capability is affected?

Connect technical evidence to bounded business dimensions such as:

- Checkout, enrollment, payment authorization, or shipment operation
- Product or channel category
- Tenant or region, when access and privacy rules permit
- Business outcome such as accepted, rejected, delayed, or compensated

Do not put customer IDs, email addresses, payment details, or arbitrary user input into high-cardinality metrics. Keep detailed business records in domain systems and use stable references or aggregated dimensions in observability data.

### 7.7 Security and Reliability Correlation

**Question:** Is a technical anomaly also a security or abuse signal?

Correlate authentication failures, unusual request patterns, service errors, and infrastructure events with SIEM workflows. Observability data can support detection and investigation, but security evidence, chain of custody, and retention requirements may require a dedicated security platform.

### 7.8 Synthetic and Real-User Observability

**Question:** Can users complete critical journeys from relevant locations and devices?

Use synthetic checks for known paths and real-user telemetry for actual client behavior. Correlate frontend errors, API traces, release versions, geography, and device class while applying consent, privacy, sampling, and data minimization controls.

### 7.9 Continuous Profiling

**Question:** Which code paths consume disproportionate CPU, memory, or wall-clock time?

Profiles complement traces. A trace identifies a slow operation; a profile can identify the code path responsible. Keep profile collection, storage, access control, and privacy policies explicit because profiles can reveal implementation details and sensitive values.

---

## 8. Data Modeling and Governance Rules

### 8.1 Required Resource Identity

At minimum, services should provide:

- `service.name`
- `service.version`
- `deployment.environment`
- Deployment or workload identity
- Region, cluster, namespace, or equivalent location metadata

The exact fields depend on the platform, but the policy must be consistent enough to answer “which service, which version, in which environment?”

### 8.2 Naming and Cardinality

- Use stable operation names and route templates.
- Prefer bounded dimensions for metrics.
- Keep raw request IDs in traces or logs only when operationally justified.
- Do not use arbitrary URLs, user input, email addresses, or secrets as metric labels.
- Version semantic conventions and validate them in CI or deployment checks.

### 8.3 Privacy and Security

Telemetry should be treated as sensitive operational data. Apply defense in depth:

1. Prevent secrets and personal data at instrumentation sources.
2. Redact and filter in the local or gateway Collector.
3. Restrict backend access by team, tenant, environment, and purpose.
4. Define retention and residency by signal and classification.
5. Audit access to detailed traces, logs, and profiles.

Observability is not an immutable audit log. Authoritative audit events need a dedicated integrity and retention model.

### 8.4 Data Quality Indicators

Measure the observability system itself:

- Percentage of services with valid resource identity
- Percentage of requests with propagated trace context
- Span, log, and metric drop rates
- Correlation success rate between signals
- Percentage of errors with actionable exception information
- Telemetry delay from event creation to query availability
- High-cardinality attribute violations
- Collector queue saturation and exporter failures

---

## 9. Operational Trade-offs

### 9.1 Cost

The unified model can increase the amount of metadata and relationship data retained. Control cost with:

- Metrics for broad, low-cost detection
- Tail sampling for errors and slow traces
- Log level and event-volume policies
- Shorter retention for high-volume raw data
- Aggregation and exemplars for metric-to-trace navigation
- Separate hot, warm, and archive tiers where appropriate
- Per-team and per-service budgets

### 9.2 Complexity

Unification introduces semantic conventions, identity management, correlation rules, and governance. Avoid forcing all teams to learn every backend. Provide a paved path with SDK defaults, Collector templates, service metadata validation, and a small set of supported workflows.

### 9.3 Reliability

Telemetry export must not block business transactions. Use asynchronous export, bounded queues, retries, timeouts, and explicit fail-open behavior. Monitor dropped telemetry and backend outages so loss is visible.

### 9.4 Tool and Vendor Independence

OpenTelemetry provides a strong instrumentation and transport foundation. It does not guarantee that every backend exposes the same semantic model or query experience. Isolate vendor-specific fields at the export or presentation boundary and keep the application contract based on portable conventions where possible.

---

## 10. Recommended Adoption Roadmap

### Phase 1: Establish the Three Signals

- Define service identity and environment metadata.
- Instrument one representative API and its dependencies.
- Collect metrics, logs, and traces through OpenTelemetry.
- Establish baseline dashboards, alerts, retention, and redaction.

### Phase 2: Make Correlation Reliable

- Propagate W3C trace context through HTTP, RPC, and messaging.
- Correlate logs with trace and span IDs.
- Standardize operation names and resource attributes.
- Add exemplars or equivalent metric-to-trace links.
- Measure telemetry loss and correlation quality.

### Phase 3: Add the Unified Context

- Emit deployment, configuration, feature-flag, and schema change events.
- Add topology and dependency relationships.
- Connect service versions and ownership metadata to runtime evidence.
- Provide investigation workflows that start from a service, operation, alert, or change.

### Phase 4: Extend to Business and Advanced Signals

- Add bounded business outcomes and user-journey context.
- Add profiles, synthetic checks, and frontend telemetry where useful.
- Integrate security workflows with clear ownership and access controls.
- Tune sampling, retention, and storage tiers using measured value and cost.

### Phase 5: Govern as a Product

- Publish supported instrumentation libraries and Collector configurations.
- Define service onboarding and quality gates.
- Review semantic conventions and breaking changes.
- Report platform reliability, adoption, cost, and investigation outcomes.

---

## 11. Proof of Concept

Use two or three services that include an HTTP request, a database dependency, and an asynchronous message flow.

### 11.1 Acceptance Criteria

| Test | Expected result |
|---|---|
| Request across two services | One trace with consistent service identity |
| Database dependency | Dependency timing is linked to the request |
| Message publish and consume | Context is propagated or an explicit relationship is visible |
| Application failure | Metric, trace, and structured log can be navigated together |
| Deployment event | A release can be compared with changes in error rate and latency |
| SLO alert | The alert identifies the affected operation and supports drill-down |
| Sensitive-data test | Deliberately supplied secrets do not reach storage |
| Backend outage | Application remains available and bounded telemetry loss is visible |
| High-cardinality test | Attribute policy prevents unbounded metric dimensions |
| Cost test | Volume, retention, and storage cost are measurable by signal |

### 11.2 Success Measures

- Time from alert to identification of the affected service and operation
- Time from identification to a plausible contributing change or dependency
- Percentage of incidents with complete cross-signal correlation
- Percentage of services meeting identity and propagation requirements
- Telemetry cost per request or per business operation
- Application CPU, memory, and latency overhead
- Signal loss and end-to-end telemetry delay

---

## 12. Recommendation

Adopt the three pillars as the operational vocabulary for producing and storing telemetry, but implement a unified data contract for identity, context, relationships, and change history.

The target state is not “one giant observability database.” It is a system in which an engineer can begin with an SLO alert, metric, log, trace, deployment, dependency, or business symptom and move to the related evidence without rebuilding the relationship manually.

OpenTelemetry is a suitable foundation because it provides APIs, SDKs, semantic conventions, context propagation, and Collector pipelines. The architecture should extend that foundation with:

1. Required resource identity and ownership metadata.
2. Consistent context propagation across service and messaging boundaries.
3. Signal-specific backends with shared correlation fields.
4. Change, topology, and business-safe event modeling.
5. Explicit privacy, retention, cardinality, and cost controls.
6. SLO and incident workflows that measure investigative outcomes.

In short, the three-pillar model answers **what kind of telemetry is being produced**. The unified model answers **how all evidence contributes to understanding the state and impact of the system**. A mature architecture needs both.
