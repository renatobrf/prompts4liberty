# Event Management Architecture for Open-Source Observability

## Executive Summary

This solution defines an event-management capability for an observability platform. It manages the lifecycle of operational events such as alerts, incidents, deployments, configuration changes, maintenance windows, telemetry pipeline failures, and service-impact notifications.

The objective is to prevent important signals from becoming disconnected notifications. The platform should normalize events, enrich them with service and ownership context, correlate related alerts, create or update incidents, route notifications, preserve an operational timeline, and support automation with controlled permissions.

```text
Telemetry, alerts, changes, and external notifications
                         |
                         v
              Event ingestion and normalization
                         |
              Correlation, deduplication, policy
                         |
                  Event backbone / queue
                         |
       +-----------------+------------------+
       |                 |                  |
 Incident state     Notification       Event history
 and workflow       and routing        and search
       |                 |                  |
       +-----------------+------------------+
                         |
                 Grafana and operator UI
```

The recommended initial design uses webhooks and OpenTelemetry-compatible metadata at the edge, a lightweight event-management service, PostgreSQL for authoritative workflow state, and an open-source event backbone only when asynchronous fan-out or buffering requires it. This avoids introducing Kafka merely to move a small number of alerts.

---

## 1. Purpose and Scope

### Objectives

| ID | Objective |
|---|---|
| EVM01 | Receive operational events from observability and delivery systems |
| EVM02 | Normalize, validate, enrich, deduplicate, and correlate events |
| EVM03 | Manage incident state, ownership, priority, and acknowledgements |
| EVM04 | Route actionable notifications to the correct team or channel |
| EVM05 | Preserve an auditable operational timeline and event history |
| EVM06 | Support automation without allowing unsafe or uncontrolled actions |
| EVM07 | Use open-source components and retain backend portability |

### In Scope

- Alerts from Grafana Alerting, Prometheus Alertmanager, and external systems
- Deployment, configuration, maintenance, and service-status events
- Telemetry pipeline events such as scrape failures, dropped data, and exporter failures
- Event normalization, correlation, deduplication, suppression, and escalation
- Incident creation, acknowledgement, assignment, resolution, and reopening
- Notification delivery through email, chat, webhooks, and compatible tools
- Searchable event history and links to metrics, logs, traces, dashboards, and runbooks
- Event governance, security, retention, and operational metrics

### Out of Scope

- Replacing a business transaction event platform
- Using observability events as a financial or legal audit record
- Automatic remediation of high-risk production operations by default
- Full project management or service desk functionality
- Replacing Grafana, Prometheus, Loki, Tempo, or OpenTelemetry

---

## 2. What Is an Observability Event?

An event is a time-bounded fact or state transition that may require investigation, communication, or action. It is not the same as a raw log line or metric sample.

| Event type | Example | Typical action |
|---|---|---|
| Alert | Checkout error rate exceeds its SLO | Investigate and notify owner |
| Incident | Customer checkout is degraded | Coordinate response and record timeline |
| Change | Version `2026.09.1` deployed | Correlate with behavior changes |
| Maintenance | Database maintenance window begins | Suppress expected alerts and inform users |
| Telemetry health | Collector is dropping spans | Repair observability pipeline |
| Dependency | Payment provider latency increases | Assess impact and escalate |
| Notification | External status update received | Update incident or timeline |
| Automation request | Scale a service or rollback a release | Validate policy and require authorization |

The event-management service should preserve the original event and its normalized representation. Normalization improves operations; it must not destroy source evidence.

---

## 3. Architectural Principles

1. **Separate signals from workflow**: Grafana and Alertmanager detect conditions; event management coordinates response.
2. **Prefer correlation over notification volume**: one incident can represent many related alerts.
3. **Use stable identity**: event ID, correlation ID, incident ID, service identity, and trace ID have different purposes.
4. **Assume at-least-once delivery**: consumers must be idempotent and duplicates must be harmless.
5. **Keep facts separate from decisions**: an observed alert, a routing rule, and an operator decision are distinct records.
6. **Fail safely**: notification failure must not lose the incident state; automation must default to no action.
7. **Preserve portability**: keep the canonical event contract independent from Kafka, NATS, RabbitMQ, or a notification vendor.
8. **Make ownership explicit**: every actionable event needs a service, team, escalation policy, and runbook where applicable.

---

## 4. Target Architecture

```text
 Grafana Alerting / Alertmanager       CI/CD and change systems
 OpenTelemetry Collector               Status pages and webhooks
 Exporters and synthetic checks        Operator/API submissions
              |                                      |
              +-------------- HTTPS / events -------+
                                     |
                         Event ingress API
                    auth, rate limit, validation
                                     |
                         Normalization service
              resource enrichment, schema validation
                                     |
                         Correlation and policy
          deduplication, grouping, suppression, escalation
                                     |
                  +------------------+------------------+
                  |                                     |
       PostgreSQL workflow state              Event backbone
       incidents, policies, outbox            Kafka/NATS/RabbitMQ
                  |                                     |
                  +------------------+------------------+
                                     |
       +-------------------+---------+----------+----------------+
       |                   |                    |                |
 Incident API       Notification workers   Timeline index   Automation worker
       |                   |                    |                |
 Grafana/UI       email/chat/webhook       PostgreSQL or      controlled actions
                                      OpenSearch/Loki          with approval
```

### 4.1 Recommended Data Flow

1. A source sends an alert or change event through an authenticated endpoint.
2. Ingress assigns or validates the event ID and records the raw payload.
3. The normalizer maps source fields to the canonical contract.
4. Enrichment adds service ownership, environment, severity defaults, runbook, and related links.
5. Correlation groups duplicates and related alerts using fingerprints, time windows, topology, and maintenance state.
6. The incident workflow creates or updates an incident transactionally.
7. An outbox publishes the resulting domain event to the event backbone.
8. Notification workers deliver messages with retry and idempotency controls.
9. Operators acknowledge, assign, annotate, escalate, or resolve the incident.
10. The timeline links the incident to dashboards, logs, traces, deployments, and changes.

The outbox is important: database state and published event state must not diverge because a process failed between two independent writes.

---

## 5. Open-Source Technology Options

### 5.1 Event Backbone Options

| Product | Strengths | Trade-offs | Best fit |
|---|---|---|---|
| Apache Kafka | High throughput, retention, replay, partitions, mature ecosystem | Operationally heavier for a small alert workload | Many producers, consumers, replay, or cross-team event streaming |
| NATS with JetStream | Lightweight, fast, simple subjects, durable streams, good request/reply | Requires careful stream and consumer design; less analytics-oriented | Small to medium event management and automation workflows |
| RabbitMQ | Mature queues, routing, acknowledgements, delayed delivery patterns | Replay and long event retention are less natural than Kafka | Work queues, notification delivery, and command processing |
| Apache Pulsar | Multi-tenancy, durable topics, geo-replication, queue and stream patterns | Higher operational complexity | Large multi-tenant or geo-distributed platforms |
| Redis Streams | Simple deployment, consumer groups, low-latency processing | Retention, durability, and scale need careful operation | Small deployments already operating Redis |
| PostgreSQL outbox and polling | Minimal components, transactional workflow state | Limited throughput and less flexible fan-out | Initial platform with low to moderate event volume |

### 5.2 Recommendation by Maturity

| Stage | Recommendation | Reason |
|---|---|---|
| Beginning | PostgreSQL plus outbox and workers | Few components and strong workflow consistency |
| Growing | NATS JetStream or RabbitMQ | Reliable asynchronous fan-out without a large platform footprint |
| Streaming platform | Apache Kafka | High volume, replay, many consumers, and long retention |
| Large multi-region | Pulsar or Kafka with established platform operations | Replication, tenancy, and scale requirements |

Kafka is a strong option, but it should be selected because replay, throughput, retention, or consumer diversity requires it, not because every event system needs a broker cluster.

### 5.3 Supporting Components

| Concern | Open-source options |
|---|---|
| Workflow state | PostgreSQL |
| Search and event exploration | OpenSearch, PostgreSQL, or Loki for operational timeline links |
| Dashboards and correlation | Grafana OSS |
| Metrics | Prometheus |
| Logs | Loki or OpenSearch |
| Traces | Tempo or Jaeger |
| Schema validation | JSON Schema, Avro with Schema Registry, or Protobuf |
| Identity and access | Keycloak, OIDC provider, mTLS, and service tokens |
| Workflow automation | Argo Events, StackStorm, Rundeck, or a constrained internal worker |

Check the current license, community health, security posture, and operational requirements of each selected product.

---

## 6. Canonical Event Contract

The canonical contract should be versioned and independent from a particular source or broker.

```json
{
  "eventId": "01J...",
  "eventType": "observability.alert.fired",
  "schemaVersion": "1.0",
  "occurredAt": "2026-09-11T12:30:45.123Z",
  "receivedAt": "2026-09-11T12:30:46.010Z",
  "source": "grafana-alerting",
  "subject": {
    "serviceName": "checkout-api",
    "environment": "production",
    "resourceId": "checkout-api/prod"
  },
  "severity": "critical",
  "correlationId": "checkout-api-prod-error-rate",
  "traceId": "optional-trace-id",
  "fingerprint": "stable-alert-fingerprint",
  "payload": {
    "status": "firing",
    "ruleName": "CheckoutErrorRateHigh",
    "value": 0.12,
    "threshold": 0.05
  },
  "links": {
    "dashboard": "https://grafana.example/d/checkout",
    "runbook": "https://docs.example/runbooks/checkout-errors"
  },
  "metadata": {
    "team": "checkout",
    "region": "us-east-1",
    "deploymentVersion": "2026.09.1"
  }
}
```

### Identity Fields

| Field | Purpose |
|---|---|
| `eventId` | Unique identity of one received event; used for deduplication |
| `eventType` | Semantic type and lifecycle action |
| `schemaVersion` | Contract compatibility and evolution |
| `correlationId` | Groups related events or one operational flow |
| `fingerprint` | Stable identity for repeated alert observations |
| `incidentId` | Identity of the workflow record created by correlation |
| `traceId` | Links the event to a distributed request when one exists |
| `source` | System that produced the event |

Do not use `traceId` as the event ID. A trace may contain many events, and some operational events have no trace.

### Event Types

Use names that describe a domain and lifecycle action:

```text
observability.alert.fired
observability.alert.resolved
observability.telemetry.degraded
observability.incident.created
observability.incident.acknowledged
observability.incident.resolved
change.deployment.started
change.deployment.completed
change.configuration.updated
maintenance.window.opened
maintenance.window.closed
notification.delivery.failed
```

---

## 7. Correlation, Deduplication, and Suppression

### 7.1 Deduplication

Use `eventId` for exact duplicate detection and `fingerprint` for repeated observations of the same condition. Store an idempotency record with a bounded retention period.

### 7.2 Correlation Signals

Correlate alerts using:

- Service name, environment, region, and cluster
- Alert fingerprint and rule family
- Time window and duration overlap
- Dependency and topology relationships
- Deployment or configuration change proximity
- Shared trace ID or request journey
- Common incident, ticket, or external reference
- Maintenance windows and planned changes

Correlation should be explainable. The incident timeline should show which rule grouped each event and allow an operator to override the result.

### 7.3 Suppression and Maintenance

Suppression is a policy decision, not deletion. Keep suppressed events in the history with the matching maintenance window or rule. Prevent notification storms while preserving evidence for later review.

### 7.4 Incident Lifecycle

```text
NEW -> TRIAGED -> ACKNOWLEDGED -> MITIGATING -> RESOLVED
  |        |             |              |            |
  +--------+-------------+--------------+------------+
                     REOPENED
```

Required incident fields should include owner, priority, impact, status, start time, latest activity, affected services, related alert fingerprints, and resolution reason.

---

## 8. Delivery and Processing Guarantees

### Recommended Defaults

- At-least-once delivery for alerts and incident events
- Idempotent consumers using event ID, fingerprint, or a domain key
- Explicit acknowledgement and retry policies
- Dead-letter queue or failed-event store for poison messages
- Exponential backoff with bounded retry duration
- Ordering only where the domain requires it, usually per incident or service key
- Replay support for selected event classes
- Transactional outbox for state changes that produce events

Exactly-once processing is usually not required. A well-designed at-least-once system with deduplication is easier to operate and recover.

### Notification Delivery

Notification workers should:

- Use a delivery key to avoid duplicate messages
- Record provider response and delivery status
- Retry transient failures only
- Avoid retrying invalid recipients or rejected payloads indefinitely
- Support escalation after an acknowledgement timeout
- Expose delivery latency and failure metrics

---

## 9. Notifications and Automation

### Routing Model

Route by service owner, severity, environment, customer impact, and time of day. Prefer team-level routing with a named escalation policy over personal addresses embedded in alert rules.

```text
Critical production incident
  -> primary service team
  -> secondary team after timeout
  -> platform coordinator when cross-service impact is detected
  -> status communication workflow when customer impact is confirmed
```

### Automation Guardrails

Automation can enrich, silence, open a ticket, scale a non-critical workload, or create a maintenance annotation. Actions such as rollback, traffic changes, data repair, or service termination should require explicit policy, authorization, audit, and preferably human approval.

Every action should record:

- Requesting principal
- Policy that allowed it
- Target and parameters
- Before and after state when available
- Result and error details
- Related incident and event IDs

---

## 10. Security and Privacy

- Authenticate every producer and consumer using OIDC, mTLS, or scoped service credentials.
- Authorize event publication and subscription by environment, team, tenant, and event type.
- Encrypt traffic and restrict broker management interfaces.
- Do not place secrets, tokens, credentials, payment data, or unnecessary personal data in event payloads.
- Apply payload size limits and schema validation at ingress.
- Protect webhook receivers with signature validation, replay protection, and rate limits.
- Separate operational event data from sensitive audit data.
- Record administrative changes to routing, suppression, escalation, and automation policies.
- Define event retention and deletion rules by event class.

An event-management system may contain incident details and customer-impact context. Access to the history should be treated as operationally sensitive.

---

## 11. Observability of Event Management

Instrument the event-management platform itself with OpenTelemetry and expose metrics for:

- Events received, accepted, rejected, duplicated, and dropped
- Ingress rate and normalization latency
- Correlation latency and incident creation rate
- Events by type, severity, service, environment, and source
- Queue depth, consumer lag, retry count, and dead-letter volume
- Notification delivery latency, failure, and duplicate rate
- Incident time to acknowledge, mitigate, and resolve
- Automation requests, approvals, failures, and executions
- Storage growth and event retention jobs

Create dashboards for ingestion health, processing health, notification health, incident workload, and policy effectiveness.

---

## 12. Ownership and Operating Model

| Responsibility | Platform team | Service team | Security team |
|---|---|---|---|
| Event platform and broker | Own | Consult | Consult |
| Canonical contract and schemas | Govern | Contribute | Consult |
| Service alerts and ownership metadata | Standards | Own | Consult |
| Correlation and routing policy | Operate shared rules | Define service rules | Review sensitive routes |
| Incident response | Coordinate platform incidents | Own service incidents | Own security incidents |
| Automation actions | Operate guardrails | Request and approve service actions | Approve high-risk actions |
| Retention and access | Implement defaults | Follow policy | Govern policy |

Maintain a catalog of event types, producers, consumers, owners, schemas, retention, replay policy, and sensitivity classification.

---

## 13. Implementation Roadmap

### Phase 0: Contract and Workflow

- Define event types, lifecycle states, required fields, and ownership.
- Choose incident priorities and escalation rules.
- Define retention, privacy, and access policies.
- Select two alert sources and one change source for the pilot.

### Phase 1: Minimal Event Management

- Implement authenticated ingress and canonical normalization.
- Persist raw events and incident workflow state in PostgreSQL.
- Add deduplication, correlation by fingerprint, and an outbox.
- Deliver notifications through one email or chat integration.
- Link incidents to Grafana dashboards and runbooks.

### Phase 2: Asynchronous Backbone

- Add NATS JetStream, RabbitMQ, or Kafka when measured fan-out or buffering requires it.
- Move notification and indexing to workers.
- Add retry, dead-letter handling, replay, and consumer metrics.
- Introduce deployment and maintenance events.

### Phase 3: Operational Intelligence

- Add topology-aware correlation and maintenance suppression.
- Add SLO burn-rate events and customer-impact classification.
- Add incident timeline search and change annotations.
- Add controlled automation and approval workflows.

### Phase 4: Scale and Governance

- Add schema registry and compatibility checks where event volume or producer diversity justifies it.
- Introduce multi-tenant isolation, regional routing, and long-term event archive if needed.
- Review event quality, alert noise, delivery reliability, and incident outcomes regularly.

---

## 14. Proof of Concept and Acceptance Criteria

Use Grafana Alerting, one CI/CD system, one service owner, and one notification channel.

| Test | Expected result |
|---|---|
| Alert fires | Canonical event is accepted, enriched, and correlated |
| Same alert repeats | No duplicate incident is created |
| Alert resolves | Existing incident is updated and resolution is notified |
| Two related alerts fire | One incident is created with both events in its timeline |
| Deployment occurs near an alert | Change appears as context without being asserted as root cause |
| Maintenance window is active | Expected alerts are suppressed from notification but retained |
| Notification provider fails | Retry and failure state are visible; incident state remains intact |
| Consumer restarts | Events are not lost and duplicate processing is harmless |
| Malformed event arrives | It is rejected or quarantined with an actionable reason |
| Unauthorized producer submits | Request is denied and recorded |
| Operator resolves incident | State transition, principal, timestamp, and reason are recorded |
| Automation is requested | Policy and authorization are checked before execution |

Measure duplicate rate, event-to-incident latency, notification latency, delivery failure rate, queue lag, dead-letter volume, and incident lifecycle times.

---

## 15. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Every alert becomes a separate incident | Notification fatigue and poor prioritization | Fingerprints, grouping, suppression, and ownership |
| Broker is introduced too early | Unnecessary operational complexity | Start with PostgreSQL outbox and workers |
| Duplicate events create duplicate actions | Repeated notifications or unsafe automation | Idempotency keys and delivery records |
| Correlation hides a real failure | Underestimated impact | Explainable rules and operator override |
| Event payload contains sensitive data | Privacy and security exposure | Schema restrictions, redaction, access control, retention |
| Notification provider is unavailable | Delayed response | Multiple channels, retries, and visible delivery state |
| Automation acts on incomplete context | Production damage | Approval, policy checks, scoped permissions, and dry runs |
| Schema changes break consumers | Event processing failures | Versioned contracts and compatibility checks |
| Event history becomes the audit system | Incorrect compliance assumptions | Keep authoritative audit records separate |

---

## 16. Recommendation

Implement event management as a thin operational coordination layer around the existing observability platform:

1. Start with Grafana Alerting or Alertmanager, CI/CD events, and authenticated webhook ingestion.
2. Use PostgreSQL for incident state, raw event records, idempotency, and an outbox in the first version.
3. Define a canonical, versioned event contract with event ID, correlation ID, fingerprint, service identity, severity, links, and source metadata.
4. Add NATS JetStream or RabbitMQ for growing asynchronous workloads; choose Kafka when replay, retention, throughput, or consumer diversity requires event streaming.
5. Use at-least-once delivery, idempotent consumers, retries, dead-letter handling, and replay controls.
6. Treat correlation, ownership, and notification policy as governed capabilities, not ad hoc alert configuration.
7. Keep automation constrained, observable, authorized, and reversible.

This design gives the observability domain a durable operational event model without forcing a large event-streaming platform into the first release. It supports a clean progression from a small PostgreSQL-backed workflow to a resilient, replayable, multi-consumer event platform.