# GenAI Log Analysis and Relevance Filtering Architecture Assessment

## Executive Summary

Generative AI can help transform a large and noisy log stream into a smaller, more useful observability dataset. It can classify events, extract operational context, cluster recurring messages, identify duplicates, summarize incident evidence, recommend retention classes, and discover which log formats contain business or operational value.

GenAI should not be given unrestricted authority to delete logs. A model can misunderstand a rare event, miss a compliance obligation, expose sensitive data to an external provider, or confidently classify an incident as irrelevant. The safe architecture uses GenAI as an analysis and recommendation layer while deterministic policy, security controls, retention rules, and explicit approvals control irreversible deletion.

The recommended strategy is:

1. Define “relevance” as a governed taxonomy before deploying a model.
2. Protect and minimize sensitive content before any model call.
3. Use deterministic filters for obvious noise, policy exclusions, and mandatory retention.
4. Use GenAI for semantic classification, extraction, clustering, and recommendation on the remaining records.
5. Store compact metadata and derived signals instead of retaining every full message indefinitely.
6. Preserve raw evidence for defined hot, warm, security, audit, legal, and incident windows.
7. Apply delayed deletion with a quarantine or reversible suppression period.
8. Evaluate the model against labeled data, especially rare failures and low-frequency business events.
9. Measure storage reduction together with missed-signal rate, investigation time, privacy risk, and model cost.
10. Replace successful GenAI discoveries with structured logging, deterministic rules, or typed fields where possible.

```text
High-volume log stream
          |
          v
Deterministic protection and mandatory-retention gates
  secrets | policy | security | audit | active incidents
          |
          v
Privacy-preserving normalization and sampling
          |
          v
GenAI classification, extraction, clustering, and recommendation
          |
          v
Policy decision engine with confidence and provenance
          |
    +-----+--------------------------+
    |                                |
Retain compact event             Retain raw evidence
metadata and signals             for approved window
    |                                |
    +---------------+----------------+
                    |
          ClickHouse and archive tiers
```

The goal is not to remove all logs. The goal is to retain the evidence and signals needed for reliability, security, compliance, customer support, capacity planning, and business operations at an economically sustainable level.

---

## 1. Purpose and Scope

### 1.1 Objectives

| ID | Objective |
|---|---|
| GLA01 | Assess GenAI for semantic log analysis and relevance classification |
| GLA02 | Define a safe process for filtering, summarizing, and discarding log content |
| GLA03 | Preserve operational, security, compliance, and business evidence |
| GLA04 | Reduce storage, query, and human investigation costs |
| GLA05 | Integrate GenAI decisions with ClickHouse and monitoring workflows |
| GLA06 | Define evaluation, governance, privacy, and rollback controls |
| GLA07 | Establish a measurable adoption path from recommendation to automation |

### 1.2 In Scope

- Application, infrastructure, integration, platform, security, and business-event logs
- GenAI classification, extraction, clustering, summarization, and anomaly explanation
- Relevance scoring and retention recommendations
- Deterministic filtering and policy enforcement around model output
- ClickHouse storage, derived fields, rollups, archives, and deletion workflows
- Grafana or comparable monitoring and investigation tools
- Model evaluation, prompt and policy versioning, data protection, and auditability

### 1.3 Out of Scope

- Allowing a model to make unreviewed irreversible deletion decisions in the first phase
- Treating model output as an authoritative legal, financial, or audit record
- Sending unredacted credentials, personal data, or regulated content to a third-party model
- Replacing structured application instrumentation with a permanent LLM dependency
- Using a generative model as the only detector for security incidents or outages

---

## 2. Decision Context

A large log platform usually contains several categories of content at the same time:

```text
Useful operational evidence
  errors, latency causes, dependency failures, deployments, saturation

Useful security or compliance evidence
  authentication, authorization, policy violations, access, investigations

Useful business context
  order, payment, shipment, customer-impact, workflow, and domain events

Low-value repetition
  successful routine requests, health checks, duplicate retries, verbose debug lines

Sensitive or prohibited content
  credentials, tokens, personal data, request bodies, secrets, regulated values
```

“Not business-relevant” does not mean “safe to delete.” A routine health check may have little business meaning but may be essential for proving availability. A failed login may not be a business transaction but may be essential to security operations. A rare error may appear only once and still explain a major incident.

The architecture must therefore distinguish at least four concepts:

| Concept | Question |
|---|---|
| Business relevance | Does the record explain or prove a business event or customer outcome? |
| Operational relevance | Does it help operate, troubleshoot, measure, or protect the platform? |
| Retention obligation | Must it be kept because of security, compliance, contract, legal hold, or policy? |
| Diagnostic value | Could it explain an unknown or future failure? |

A record can have low business relevance and high operational or retention value. Deletion policy must use all of these dimensions.

---

## 3. What GenAI Can and Cannot Do

### 3.1 Suitable GenAI Tasks

| Task | Example output | Recommended use |
|---|---|---|
| Semantic classification | `routine_success`, `dependency_failure`, `security_signal` | Candidate relevance and retention class |
| Field extraction | Dependency, operation, customer-impact hint, error cause | Enrichment and investigation |
| Message clustering | Groups of equivalent or near-equivalent messages | Noise reduction and format discovery |
| Template discovery | Finds stable variable portions of messages | Structured logging migration |
| Summarization | Incident timeline and representative evidence | Human investigation assistance |
| Pattern recommendation | Proposed rule for a recurring failure family | Review and promotion to deterministic logic |
| Schema mapping | Maps legacy text to a canonical event model | Migration and normalization |
| Anomaly explanation | Describes what changed in an unusual cluster | Analyst assistance, not sole alerting |

### 3.2 Unsuitable or High-Risk Tasks

- Final deletion of records needed for legal, security, audit, or incident purposes.
- Determining business materiality without domain context and ownership.
- Treating the absence of a matching message as proof that an event did not occur.
- Handling secrets or regulated data through an external model without an approved data boundary.
- Replacing exact metrics, traces, audit events, or service-level indicators.
- Making high-impact production decisions from a free-form summary without source evidence.

### 3.3 Recommended Role of the Model

Use GenAI as a probabilistic semantic layer:

```text
Raw event
  -> model-derived labels, fields, confidence, and explanation
  -> deterministic policy evaluation
  -> retention, routing, rollup, or quarantine decision
```

The policy engine must be able to override the model. Mandatory-retention rules, active incident holds, security rules, and legal holds must take precedence over a low relevance score.

---

## 4. Relevance and Retention Taxonomy

Before model training, prompting, or deployment, define a taxonomy that maps analysis to action.

### 4.1 Recommended Classes

| Class | Meaning | Default treatment |
|---|---|---|
| `mandatory_retain` | Security, audit, legal, regulatory, or approved contractual evidence | Preserve according to policy; model cannot discard |
| `incident_evidence` | Linked to an active or recently closed incident | Preserve raw evidence through the incident window |
| `business_event` | Explains a customer, order, payment, fulfillment, or domain outcome | Retain required fields and policy-defined raw content |
| `operational_failure` | Error, timeout, dependency failure, saturation, or data-quality issue | Retain raw short term; retain derived signal longer |
| `security_signal` | Authentication, authorization, suspicious activity, or policy event | Route to security controls and retain by security policy |
| `change_evidence` | Deployment, configuration, feature flag, schema, or infrastructure change | Retain with deployment and service identity |
| `diagnostic_context` | Useful context for troubleshooting but not independently important | Retain short term or sample by policy |
| `routine_success` | Repetitive successful operation with no unusual attributes | Aggregate; keep sampled or compact metadata |
| `health_check` | Synthetic, readiness, liveness, or availability evidence | Aggregate into metrics; preserve failures and samples |
| `duplicate_noise` | Repeated record with no additional information | Deduplicate or retain counts and representative samples |
| `unknown` | Model or rules cannot determine value | Preserve until reviewed or expires under a conservative policy |

The `unknown` class is important. Uncertainty must not be silently converted into deletion.

### 4.2 Retention Classes

Relevance class and retention class should be separate. A security signal and a business event may have different legal and operational periods even when both are important.

| Retention class | Content | Example treatment |
|---|---|---|
| R0 | Prohibited or unnecessary sensitive content | Redact before storage or reject at the edge |
| R1 | Routine repetitive content | Aggregate, sample, and short retention |
| R2 | General operational context | Hot retention followed by compact metadata |
| R3 | Errors, changes, dependencies, customer-impact evidence | Longer raw and derived retention |
| R4 | Security, audit, legal hold, or regulated evidence | Policy-defined protected storage |
| R5 | Active incident evidence | Hold until incident owner releases it |

Retention periods must be approved by security, legal, privacy, compliance, and service owners where applicable. They must not be inferred solely from a model label.

---

## 5. Target Architecture

```text
 Applications, hosts, Kubernetes, gateways, vendors
                         |
                         v
       Collector and deterministic protection layer
  size limits | secret redaction | policy bypass | metadata
                         |
                         v
                Durable event buffer
             Kafka, Redpanda, or queue
                         |
             +-----------+------------+
             |                        |
  Mandatory and deterministic      GenAI analysis workers
  policy decisions                 classify | extract | cluster
  security | audit | incident     summarize | recommend
             |                        |
             +-----------+------------+
                         v
              Relevance policy engine
       confidence | overrides | retention | provenance
                         |
         +---------------+----------------+
         |                                |
  ClickHouse event index              Object storage archive
  typed fields, derived labels,       protected raw or compact
  rollups, investigation views        evidence by retention class
         |
         v
      Grafana, security tools, incident workflows, APIs
```

### 5.1 Processing Stages

#### Stage 1: Ingest and Protect

- Authenticate the producer or collector.
- Attach event time and trusted ingestion time.
- Enforce maximum event size and rate limits.
- Redact obvious credentials and prohibited values using deterministic rules.
- Extract stable fields such as service, environment, severity, trace ID, and request ID.
- Apply mandatory retention and active-incident bypass rules.

#### Stage 2: Normalize and Sample

- Normalize timestamps, severity, source, service, and environment.
- Identify duplicate events and retry storms.
- Preserve error and security records even when routine successes are sampled.
- Create a compact input representation for the model.
- Remove fields that do not contribute to classification.

#### Stage 3: GenAI Analysis

- Classify relevance and retention candidates.
- Extract dependency, operation, error family, customer-impact, and change context.
- Cluster similar messages and identify representative examples.
- Produce confidence, model version, prompt version, and evidence references.
- Route uncertain or high-impact records for review.

#### Stage 4: Policy Decision

- Apply mandatory-retention overrides.
- Apply tenant, region, legal, security, and incident policies.
- Reject model output that lacks required fields or confidence.
- Select full raw retention, compact retention, aggregation, quarantine, or discard-after-delay.
- Write the decision and reason to an audit stream.

#### Stage 5: Store and Serve

- Store typed metadata and derived classifications in ClickHouse.
- Retain raw content only for the approved period and class.
- Store archive material in protected object storage where required.
- Expose aggregate signals, representative examples, and source links to Grafana.
- Keep enough provenance to explain why content was retained, transformed, or discarded.

---

## 6. GenAI Processing Patterns

### 6.1 Classification

A classifier can assign labels such as `routine_success`, `operational_failure`, or `security_signal`. The output should be structured rather than free-form:

```json
{
  "relevance_class": "operational_failure",
  "retention_candidate": "R3",
  "error_family": "payment_timeout",
  "customer_impact": "possible",
  "confidence": 0.93,
  "evidence": ["payment provider", "deadline exceeded"],
  "model_version": "log-classifier-2026-09-01",
  "policy_input_version": "retention-policy-4"
}
```

The model must not return only a prose answer. Structured output makes validation, policy evaluation, metrics, and rollback possible.

### 6.2 Clustering and Template Discovery

Large log streams often contain many messages that differ only in identifiers, timestamps, or values. GenAI can help cluster semantically similar messages and discover templates:

```text
"GET /orders/123 returned 200 in 42 ms"
"GET /orders/456 returned 200 in 38 ms"
"GET /orders/789 returned 200 in 41 ms"
                         |
                         v
request_success_template, route=/orders/:id, status=200
```

Once validated, the template should become a deterministic parser or structured field. Re-running a model for every identical routine message is usually unnecessary and expensive.

### 6.3 Summarization

For incident response, GenAI can summarize a bounded evidence set:

```text
Time window + service + incident ID
  -> metrics, traces, classified logs, deployments
  -> summary with cited event IDs and timestamps
```

A summary should link to source records and distinguish observed facts from hypotheses. It should never replace the underlying evidence or become the only retained representation for mandatory data.

### 6.4 Recommendation and Rule Promotion

GenAI can propose:

- a regex or parser for a recurring format,
- a new structured field,
- a retention class,
- a duplicate key,
- a rollup dimension,
- a dashboard or alert query.

Proposals must pass tests and owner approval before affecting ingestion or deletion. The model should help create deterministic logic, not create an invisible collection of changing prompts in production.

---

## 7. Privacy and Model Boundary

### 7.1 Data Minimization Before the Model

The model input should be smaller and safer than the raw log whenever possible:

```text
Raw log
  -> remove credentials, tokens, request bodies, and direct identifiers
  -> keep service, severity, bounded message, error code, and context
  -> classify only the minimum required content
```

Use a local or privately hosted model when policy prohibits sending log content outside the controlled environment. For a managed model, verify training retention, regional processing, encryption, tenant isolation, contractual terms, and provider access controls.

### 7.2 Sensitive Data Controls

- Redact secrets before model inference, not after.
- Mask or tokenize personal identifiers unless they are required for an approved workflow.
- Do not include authorization headers, cookies, passwords, private keys, or full request bodies by default.
- Apply field-level classification before building prompts.
- Keep prompt, response, and model telemetry free of raw sensitive content where possible.
- Restrict who can inspect model inputs and outputs.
- Define deletion behavior for model caches, vector indexes, and inference logs.
- Test redaction with real format variants and adversarial examples.

### 7.3 Embeddings and Vector Search

Embeddings can help find semantically similar messages and clusters, but they create another retained representation of the data. Treat vectors as sensitive derived data:

- apply the same access and retention classification as the source,
- avoid embedding secrets or prohibited content,
- keep links to source records and model versions,
- define how vectors are deleted when the source is deleted,
- prevent cross-tenant similarity searches without authorization.

Vector search is an optional investigation aid. It should not be required for basic retention enforcement.

---

## 8. Safe Discard and Data Lifecycle

### 8.1 Never Discard Directly from a Model Score

A score such as `irrelevance=0.97` is not a deletion authorization. Use a policy decision with overrides and a delay:

```text
Model recommendation
      |
      v
Mandatory retention and incident hold checks
      |
      v
Confidence and policy threshold checks
      |
      v
Quarantine or suppression window
      |
      v
Sampling and human audit
      |
      v
Reversible or final deletion according to policy
```

### 8.2 Two-Stage Deletion

Use a delayed lifecycle for content that is a candidate for discard:

1. **Candidate**: model and deterministic rules classify the record as low value.
2. **Quarantine**: retain it in lower-cost or restricted storage for a defined review period.
3. **Audit sample**: periodically inspect random and targeted samples.
4. **Release or hold**: retain records that reveal incidents, drift, or policy exceptions.
5. **Delete**: apply the approved retention policy and record the deletion decision.

The quarantine period should be long enough to detect delayed incident relationships and producer changes. Its duration is a policy decision, not a model parameter.

### 8.3 What to Retain When Full Content Is Discarded

For low-value repetitive logs, retain compact evidence such as:

```text
event_time_bucket
service_name
environment
region
log_template_id
relevance_class
retention_class
count
first_seen
last_seen
sample_event_id
status_code
route
error_family
trace_or_incident_link
parser_version
policy_decision_version
```

This preserves trend, volume, and representative investigation context without retaining every identical message. Do not use compact metadata to satisfy a requirement that explicitly requires the original record.

### 8.4 Mandatory Holds

A record or related cluster must be protected from discard when:

- linked to an active incident,
- linked to a security investigation,
- under legal hold,
- required by audit, regulatory, or contractual policy,
- part of a suspected data-loss or fraud investigation,
- needed for an approved recovery or replay procedure,
- selected for an ongoing model or parser evaluation set.

Holds must be explicit, time-bounded where possible, owned, and auditable.

---

## 9. ClickHouse Storage Design

### 9.1 Store Derived Metadata as Typed Columns

The GenAI output should be validated and stored as typed fields, not only as a large JSON response:

```sql
ALTER TABLE observability.logs_local
ADD COLUMN relevance_class LowCardinality(String),
ADD COLUMN retention_class LowCardinality(String),
ADD COLUMN error_family LowCardinality(String),
ADD COLUMN ai_confidence Float32,
ADD COLUMN ai_model_version LowCardinality(String),
ADD COLUMN policy_decision LowCardinality(String),
ADD COLUMN policy_version LowCardinality(String),
ADD COLUMN analysis_time DateTime64(3, 'UTC');
```

The exact migration strategy depends on the current table and deployment process. High-cardinality free-form explanations should not become an unbounded primary dimension.

### 9.2 Raw and Compact Tables

A practical design can separate raw content from compact derived events:

```text
observability.logs_raw
  approved raw messages, short hot retention, protected access

observability.logs_compact
  typed metadata, classifications, counts, templates, longer retention

observability.logs_archive
  policy-controlled object-storage records for required classes

observability.logs_quarantine
  candidate-discard records during the review window
```

The compact table should not silently lose the link to raw evidence. Use stable event IDs, cluster IDs, incident IDs, or sample references.

### 9.3 Rollup Example

```sql
SELECT
    toStartOfMinute(event_time) AS minute,
    service_name,
    environment,
    relevance_class,
    error_family,
    count() AS event_count,
    uniqExact(trace_id) AS trace_count
FROM observability.logs_compact
WHERE event_time >= {from:DateTime64}
  AND event_time < {to:DateTime64}
GROUP BY
    minute,
    service_name,
    environment,
    relevance_class,
    error_family
ORDER BY minute, service_name;
```

Use rollups for high-frequency monitoring panels. Keep the raw table for bounded drill-down according to retention policy.

### 9.4 Deletion and TTL

ClickHouse TTL can enforce time-based movement or deletion, but it cannot replace policy evaluation, incident holds, or independent audit records. A deletion workflow should:

- mark the approved retention class,
- check for holds,
- record policy and model provenance,
- move content to the correct volume or archive,
- apply deletion only after the delay,
- verify deletion behavior in replicas and backups,
- track deletion failures and backlog.

Do not allow a model to issue arbitrary `DELETE` statements against production tables.

---

## 10. Monitoring the GenAI Pipeline

The GenAI system needs observability of its own behavior.

### 10.1 Pipeline Metrics

| Metric | Why it matters |
|---|---|
| Input records and bytes | Measures workload and cost |
| Model requests and tokens | Measures model usage and spend |
| Inference latency | Detects pipeline delay |
| Timeout and error rate | Shows model dependency health |
| Classification distribution | Detects drift or prompt failure |
| Unknown and low-confidence rate | Shows uncertainty and review load |
| Mandatory override rate | Shows policy boundary activity |
| Candidate-discard rate | Controls storage-reduction behavior |
| Quarantine backlog | Shows whether review can keep up |
| Rollback count | Shows production safety events |
| False-positive and false-negative samples | Measures quality |
| Storage reduction | Measures economic value |

### 10.2 Drift Signals

Alert on changes such as:

- routine-success share suddenly increasing or decreasing,
- error-family distribution changing after a deployment,
- unknown rate rising for one service,
- model confidence increasing while human accuracy decreases,
- token usage increasing because messages became longer,
- new clusters appearing without owners,
- security or mandatory-retention overrides being classified as routine.

A model can remain available while becoming semantically wrong. Distribution monitoring is therefore as important as endpoint health.

---

## 11. How GenAI Produces Wins

The value should be measured against a baseline rather than described as “AI efficiency.”

### 11.1 Storage and Infrastructure Reduction

GenAI can identify repetitive routine records and convert them into counts, templates, and representative samples. The potential win is lower hot storage, lower backup volume, lower query scan cost, and fewer archive objects.

Measure:

```text
raw bytes received
- retained raw bytes
- compact metadata bytes
= discarded or compressed bytes
```

Also include model compute, inference API, review, and archive costs. A storage reduction is not a win if model processing costs more than the avoided storage and operations.

### 11.2 Faster Incident Investigation

Semantic grouping can turn thousands of textual variants into a small set of failure families. Summaries can identify likely dependencies, recent changes, and representative evidence.

Measure:

- time from alert to first useful hypothesis,
- time to find representative evidence,
- number of raw log queries per incident,
- percentage of incidents with a linked error family,
- operator agreement with the generated summary.

### 11.3 Reduced Logging Debt

GenAI can discover repeated templates, missing context, and inconsistent field names across services. This creates a prioritized backlog for structured logging and OpenTelemetry adoption.

Measure:

- number of formats discovered,
- percentage mapped to canonical fields,
- number of producers migrated,
- unmatched and unknown rates over time,
- reduction in regex and prompt rules after producer improvements.

### 11.4 Better Data Protection

Automated classification and redaction assistance can identify sensitive values that deterministic rules do not yet cover. The model should recommend or flag; deterministic redaction and security review should enforce.

Measure:

- sensitive-value detection rate,
- confirmed leakage rate,
- time to remediate a new sensitive format,
- sampled false-negative rate,
- percentage of log sources covered by tested redaction rules.

### 11.5 Better Capacity and Reliability Signals

A model can classify routine versus abnormal patterns, identify retry storms, and explain changes in message distributions. These outputs can improve dashboards and reduce noisy alerts when combined with metrics and traces.

Measure:

- alert precision and noise reduction,
- time to detect format drift,
- duplicate or retry volume reduction,
- correlation between model clusters and known incidents,
- changes in mean time to detect and resolve.

---

## 12. Evaluation and Governance

### 12.1 Labeled Evaluation Set

Build a versioned evaluation set containing:

- routine successful operations,
- known outages and incidents,
- rare but important failures,
- security and authentication events,
- business-impacting domain events,
- deployments and configuration changes,
- duplicate and retry storms,
- sensitive data variants,
- unknown and malformed formats,
- examples from every critical service and producer version.

The set must include records that occur rarely. A model that performs well on common health checks but discards the one event explaining a severe incident is not acceptable.

### 12.2 Quality Measures

| Measure | Meaning |
|---|---|
| Precision of low-value class | How much classified noise is truly low value |
| Recall of protected classes | How much mandatory or important evidence is preserved |
| False-discard rate | Important content incorrectly eligible for deletion |
| Unknown rate | Content requiring conservative handling or review |
| Confidence calibration | Whether confidence corresponds to correctness |
| Cluster purity | Whether grouped messages have the same operational meaning |
| Extraction accuracy | Correctness of derived fields |
| Summary faithfulness | Whether summaries are supported by source evidence |
| Drift resilience | Quality across producers, versions, and incidents |
| Cost per analyzed event | Total model and infrastructure cost |

For deletion candidates, recall of protected content is more important than precision of noise detection. The risk of discarding an important record should dominate the desire to maximize storage reduction.

### 12.3 Human Review

Human review should focus on:

- low-confidence classifications,
- new message clusters,
- records proposed for deletion with high diagnostic uncertainty,
- security and compliance boundary cases,
- changes in class distribution,
- model or prompt version changes.

Review decisions should become labeled examples and policy improvements. Do not treat review as an informal exception process that is invisible to the system.

### 12.4 Model and Prompt Governance

Version and audit:

- model name and version,
- prompt or task template version,
- input transformation version,
- policy version,
- classifier output schema,
- evaluation set version,
- decision timestamp,
- reviewer or automated override,
- source event and cluster identifiers.

A model update must be tested in shadow mode before it can influence retention recommendations. Keep the previous version available for comparison and rollback.

---

## 13. Security and Compliance Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Sensitive logs sent to an external model | Privacy, contractual, or regulatory exposure | Redaction, private deployment, approved provider boundary |
| Model discards rare incident evidence | Missed diagnosis and lost accountability | Mandatory classes, conservative thresholds, holds, delayed deletion |
| Prompt injection in log content | Model follows instructions embedded in untrusted logs | Treat logs as data, delimit content, structured output, ignore embedded instructions |
| Hallucinated classification or summary | Incorrect operational decisions | Source citations, confidence, deterministic policy, human review |
| Model drift | Retention and detection quality changes silently | Distribution monitoring, evaluation, shadow deployments |
| Data leakage through prompts or traces | Sensitive content in observability systems | Minimize inputs and protect model telemetry |
| Cross-tenant inference | Confidentiality breach | Tenant isolation, separate context, access policy, no unauthorized similarity search |
| Uncontrolled inference cost | Budget overrun | Sampling, batching, model tiers, caching, quotas |
| Hidden deletion logic | Unreviewed policy change | Versioned rules, audit events, change approval |
| Provider dependency | Availability and portability risk | Local fallback, queueing, deterministic baseline, model abstraction |

Treat log content as untrusted input. Logs may contain text that looks like instructions, fabricated fields, or attacker-controlled payloads. The model must not be allowed to execute actions based on log text.

---

## 14. Failure Modes and Fallbacks

The platform must remain useful when the model is unavailable or unreliable.

| Failure | Required behavior |
|---|---|
| Model unavailable | Queue, use deterministic baseline, or retain conservatively |
| High latency | Bypass analysis for mandatory and high-priority logs; preserve raw evidence temporarily |
| Invalid structured output | Mark unknown and route to review or quarantine |
| Confidence below threshold | Do not discard; retain according to conservative class |
| Prompt or model regression | Stop automated retention recommendations and roll back |
| Policy service unavailable | Fail closed for deletion; preserve candidate content |
| Archive unavailable | Do not delete the only approved copy |
| Unexpected class distribution | Trigger drift alert and hold deletion candidates |
| ClickHouse unavailable | Buffer or route to durable archive; preserve deletion decisions separately |

The safe default for uncertainty is retention, not deletion.

---

## 15. Proof of Concept

The proof of concept should begin in shadow mode. The model analyzes records and produces recommendations, but no content is deleted automatically.

### 15.1 POC Scope

Select a representative slice containing:

- one high-volume routine service,
- one service with meaningful failures,
- one legacy or poorly structured producer,
- one security-sensitive source,
- one business workflow with customer impact,
- recent incidents and normal operating periods.

Compare:

1. raw retention without GenAI,
2. deterministic filtering and aggregation,
3. GenAI recommendations with human review,
4. promoted rules or structured fields after validation.

### 15.2 POC Stages

#### Stage A: Shadow Classification

- Redact and minimize inputs.
- Classify records without changing retention.
- Compare model outputs with labeled samples and operator judgment.
- Measure token usage, latency, confidence, and class distribution.

#### Stage B: Candidate Compaction

- Convert only high-confidence routine duplicates into counts and representative samples.
- Keep raw candidates in quarantine.
- Run incident reconstruction exercises against compacted and original data.
- Verify that important evidence remains discoverable.

#### Stage C: Delayed Automation

- Apply policy-approved discard only after quarantine and sample review.
- Keep mandatory-retention and incident-hold overrides active.
- Test model rollback, policy rollback, and archive restore.

#### Stage D: Rule and Schema Promotion

- Convert stable findings into deterministic parsers, typed fields, metrics, or retention rules.
- Reduce model calls for repeated, well-understood patterns.
- Re-evaluate cost and quality after promotion.

### 15.3 Acceptance Criteria

| Area | Example target |
|---|---|
| Protected recall | No unacceptable loss of labeled security, incident, audit, or business-critical evidence |
| Storage reduction | Approved reduction after including model, review, archive, and infrastructure cost |
| Investigation | Incident reconstruction works with retained raw and compact evidence |
| Privacy | No unapproved sensitive content reaches the model boundary |
| Confidence | Low-confidence and unknown records follow conservative retention behavior |
| Cost | Inference cost stays within the approved budget per million events |
| Latency | Analysis does not exceed the ingestion freshness or buffer budget |
| Drift | Distribution changes generate an alert before automated deletion expands |
| Reversibility | Candidate content can be restored or held during the quarantine period |
| Auditability | Every retention and deletion decision has policy, model, and source provenance |

---

## 16. Adoption Path

### Phase 1: Define value and policy

- Inventory log sources, business workflows, incidents, security needs, and retention obligations.
- Define relevance and retention classes with owners.
- Identify prohibited content and approved model boundaries.
- Baseline storage, ingestion, query cost, incident time, and current data loss.

### Phase 2: Analyze without deleting

- Implement deterministic redaction and mandatory-retention gates.
- Run GenAI in shadow mode on minimized records.
- Create the labeled evaluation set and measure quality.
- Build dashboards for confidence, unknowns, drift, and cost.

### Phase 3: Compact and quarantine

- Aggregate high-confidence repetitive routine logs.
- Keep raw candidates in a lower-cost quarantine tier.
- Perform random and incident-focused audits.
- Validate investigation workflows using compact evidence and representative samples.

### Phase 4: Controlled automation

- Automate only approved classes with delayed deletion.
- Keep model output subordinate to policy and incident holds.
- Audit deletion decisions and monitor protected-class recall.
- Provide a rapid kill switch and rollback path.

### Phase 5: Replace AI parsing with durable contracts

- Promote stable findings to structured fields, metrics, parsers, or deterministic rules.
- Improve producer logging and OpenTelemetry instrumentation.
- Retire prompts and models that no longer add measurable value.
- Keep GenAI for discovery, clustering, summarization, and changing or ambiguous formats.

---

## 17. Recommendation

Proceed with GenAI as a supervised semantic analysis layer for log relevance, classification, clustering, summarization, and migration discovery. Do not use it as an autonomous deletion authority.

The minimum production architecture should include:

- deterministic redaction and mandatory-retention gates before model inference,
- a durable buffer and conservative fallback when the model is unavailable,
- minimized and privacy-classified model inputs,
- structured model output with confidence, provenance, and version identifiers,
- a policy engine that overrides model recommendations,
- `unknown` and low-confidence handling that retains data conservatively,
- quarantine and delayed deletion for discard candidates,
- compact metadata, counts, templates, and representative samples for routine content,
- ClickHouse typed fields and rollups for efficient monitoring queries,
- object-storage archive and explicit legal, security, and incident holds,
- labeled evaluation data containing rare failures and protected events,
- monitoring for drift, protected recall, inference cost, match distribution, and deletion backlog,
- a path to replace stable AI-derived behavior with structured logging and deterministic rules.

The main win is controlled reduction of noise and storage while preserving the evidence required to operate, protect, investigate, and improve the business. The architecture is successful only when it can prove both sides of that statement: less unnecessary content, and no unacceptable loss of important content.
