# ClickHouse Log Index Architecture Assessment

## Executive Summary

This assessment evaluates ClickHouse as a high-volume log storage, filtering, and indexing platform for an observability solution. The target system must ingest a large and sustained volume of structured logs, retain them according to operational and compliance policies, support fast filtering and aggregation, and expose the data to a monitoring tool such as Grafana.

ClickHouse is a strong fit when the workload is dominated by append-only events, time-range searches, aggregations, error analysis, service exploration, and operational dashboards. It should be treated as a column-oriented analytical database rather than as a conventional transactional database or a generic full-text search engine.

The recommended architecture is:

1. Produce structured logs with stable service, environment, severity, timestamp, trace, and request attributes.
2. Collect and buffer logs through OpenTelemetry Collector, Vector, Fluent Bit, or a durable event backbone.
3. Normalize and enrich records before insertion into ClickHouse.
4. Store recent and frequently queried logs in MergeTree tables ordered for the dominant investigation paths.
5. Use materialized views or derived tables for common aggregations, not as a substitute for the raw event table.
6. Apply TTL, tiered storage, and archive policies to control cost.
7. Connect Grafana or another monitoring tool through the ClickHouse data source, with query limits and access controls.
8. Keep an object-storage archive when retention, replay, legal preservation, or disaster recovery requires data beyond the ClickHouse operating window.

ClickHouse is recommended as the primary analytical log index when predictable query patterns, high ingestion volume, and cost-efficient aggregation matter more than arbitrary text relevance ranking. A search engine may still be appropriate for advanced linguistic search, fuzzy matching, or document-oriented workflows.

---

## 1. Purpose and Scope

### 1.1 Objectives

| ID | Objective |
|---|---|
| CHL01 | Assess ClickHouse for large-scale log ingestion and analytical search |
| CHL02 | Define a durable ingestion and buffering path for burst traffic |
| CHL03 | Propose a schema and sort key that support operational investigation |
| CHL04 | Define retention, tiering, deletion, and archive strategies |
| CHL05 | Integrate ClickHouse with a monitoring and dashboarding tool |
| CHL06 | Identify performance, availability, security, and cost risks |
| CHL07 | Establish a validation plan with measurable acceptance criteria |

### 1.2 In Scope

- Application, infrastructure, platform, security, and integration logs
- Structured JSON or equivalent normalized event records
- High-volume append-only ingestion
- Time-range filtering, service filtering, severity filtering, trace correlation, and aggregation
- Grafana or a comparable monitoring interface
- Replication, sharding, backups, object-storage integration, and operational governance
- PII handling, retention, access control, query protection, and cost management

### 1.3 Out of Scope

- Transactional business workflows requiring frequent row updates
- ClickHouse as the authoritative audit or financial system of record
- Unrestricted arbitrary full-text relevance ranking
- Replacing metrics and traces with logs
- Automatic deletion of data without a documented retention policy

---

## 2. Decision Context

A log platform has two different responsibilities:

```text
Log producers
    |
    v
Collection, validation, enrichment, buffering
    |
    v
Durable analytical storage and indexing
    |
    +--> Investigation queries and dashboards
    +--> Alerts and scheduled analysis
    +--> Archive, replay, and governance
```

The database should not be the only buffer between log producers and operators. A database outage, network partition, schema change, or ingestion spike must not immediately cause silent log loss. The ingestion layer must expose its own health metrics and make loss, delay, retry, and backpressure visible.

### 2.1 Workload Assumptions to Confirm

The following values must be measured before final capacity sizing:

| Dimension | Required measurement |
|---|---|
| Ingestion rate | Average and peak events per second |
| Data rate | Average and peak uncompressed and compressed bytes per second |
| Event size | p50, p95, p99, and maximum record size |
| Cardinality | Distinct services, hosts, traces, users, tenants, and dynamic fields |
| Query mix | Recent searches, historical searches, aggregations, dashboards, and alerts |
| Concurrency | Simultaneous users, scheduled queries, and API clients |
| Retention | Hot, warm, archive, and deletion periods |
| Availability | Recovery point and recovery time objectives |
| Compliance | Data residency, deletion, masking, and legal hold requirements |

Sizing from average daily volume alone is unsafe. The design must account for peak ingestion, replication, temporary merge amplification, indexes, backups, and growth.

---

## 3. Why ClickHouse Fits This Workload

### 3.1 Strengths

- Columnar compression is effective for repeated log fields such as service, severity, environment, and status.
- MergeTree tables are optimized for append-heavy workloads and time-oriented analysis.
- Parallel execution supports high-throughput filtering and aggregation.
- Replication and distributed tables support horizontal scale and availability.
- TTL policies can move or delete data automatically.
- Materialized views can maintain rollups for frequent dashboards and alert queries.
- SQL provides a familiar interface for analysts, operators, Grafana, and automation.
- Object-storage disks and backups support lower-cost retention tiers.

### 3.2 Constraints

- ClickHouse is not a row-oriented transactional database.
- Updates and deletes are more expensive than appends and should be exceptional operations.
- Query speed depends heavily on the table `ORDER BY`, time predicates, and data skipping.
- Arbitrary substring searches can scan a large amount of data even when the query is syntactically simple.
- High-cardinality, unbounded fields can reduce compression and increase memory use.
- Distributed queries can multiply work when the same dashboard issues broad scans.
- Background merges consume CPU, disk, and I/O and must be included in capacity planning.
- Replication improves availability but does not replace backups or archive retention.

### 3.3 Appropriate Search Semantics

| Search need | ClickHouse suitability | Guidance |
|---|---|---|
| Time range plus service and severity | Excellent | Use typed columns and a time-aware sort key |
| Error counts by service and release | Excellent | Use aggregation and optional rollup tables |
| Trace ID or request ID lookup | Excellent | Store identifiers as dedicated columns |
| Exact field match | Excellent | Use typed columns or materialized normalized fields |
| Prefix search on a bounded field | Good | Consider a suitable data-skipping index and test it |
| Arbitrary substring search in message text | Variable | Test realistic data; expect scans without additional design |
| Fuzzy relevance ranking | Limited | Consider a search engine or specialized workflow |
| Frequent record mutation | Poor fit | Keep mutable state in another database |

---

## 4. Target Architecture

```text
 Applications, hosts, Kubernetes, gateways, security tools
                         |
                         v
        OpenTelemetry Collector / Vector / Fluent Bit
       parse, batch, enrich, redact, sample, route, retry
                         |
             +-----------+------------+
             |                        |
       Durable event buffer       Dead-letter path
       Kafka / Redpanda /          invalid or rejected
       object-storage queue              records
             |
             v
       ClickHouse ingest consumers
      async inserts, idempotency,
      compression, schema validation
             |
   +---------+------------------+
   |                            |
Raw log events              Derived data
MergeTree tables             materialized views,
                              rollups, alerts
   |                            |
   +-------------+--------------+
                 |
          Grafana / API / SQL clients
                 |
      dashboards, investigation, alerting

ClickHouse storage:
  local fast disk for hot data
  object storage for warm/cold data and backup
  replicated nodes coordinated by ClickHouse Keeper
```

### 4.1 Ingestion Responsibilities

The collector or ingest service should:

- Attach a trusted ingestion timestamp in addition to the producer timestamp.
- Normalize severity, service identity, environment, region, and source type.
- Preserve the original message or payload where policy permits.
- Extract trace ID, span ID, request ID, and correlation ID into dedicated fields.
- Redact or tokenize sensitive values before they reach shared storage.
- Batch records and compress inserts to reduce network and part overhead.
- Apply bounded retries and expose backpressure rather than retrying forever.
- Route malformed records to a dead-letter path with an actionable reason.
- Reject or quarantine records that violate size, schema, or security limits.

The collector is not the source of truth for delivery. If losing logs is unacceptable, use a durable buffer or a producer-side queue with a defined retention window.

### 4.2 ClickHouse Deployment Shapes

| Shape | Description | Appropriate when |
|---|---|---|
| Single server | One ClickHouse node with local storage | Development, proof of concept, or non-critical data |
| Replicated pair | Two or more replicas per shard coordinated by Keeper | Production availability with moderate scale |
| Sharded cluster | Multiple shards, each with replicas | Ingestion or storage exceeds a node's practical capacity |
| Managed ClickHouse | Provider operates infrastructure and some reliability concerns | The team wants analytical capability without operating the cluster |

The first production design should prefer the smallest topology that meets availability and throughput requirements. Sharding adds operational and query-routing complexity; it should be justified by measured capacity rather than assumed from the word “huge.”

---

## 5. Data Model

### 5.1 Recommended Raw Log Table

The exact schema should be adapted to the log contract, but stable investigation dimensions should be first-class columns. Dynamic or rarely queried attributes can remain in a bounded map or JSON representation.

```sql
CREATE TABLE observability.logs_local
(
    event_time       DateTime64(3, 'UTC'),
    ingest_time      DateTime64(3, 'UTC') DEFAULT now64(3),
    event_date       Date MATERIALIZED toDate(event_time),

    service_name     LowCardinality(String),
    environment      LowCardinality(String),
    region           LowCardinality(String),
    source_type      LowCardinality(String),
    host_name        String,
    container_name   String,
    severity         LowCardinality(String),
    log_level        LowCardinality(String),

    trace_id         String,
    span_id          String,
    request_id       String,
    correlation_id   String,

    logger           LowCardinality(String),
    message          String,
    error_type       LowCardinality(String),
    error_message    String,
    http_method      LowCardinality(String),
    http_route       String,
    status_code      Nullable(UInt16),
    duration_ms      Nullable(UInt32),

    attributes       Map(LowCardinality(String), String),
    raw_payload      String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/observability/logs_local',
    '{replica}'
)
PARTITION BY toYYYYMM(event_date)
ORDER BY
(
    event_date,
    service_name,
    environment,
    severity,
    event_time,
    trace_id
)
TTL event_time + INTERVAL 30 DAY TO VOLUME 'warm',
    event_time + INTERVAL 180 DAY DELETE;
```

The example is a starting point, not a universal schema. In particular, the `ORDER BY` must be selected from real query traces. Adding every possible field to the sort key is harmful: it increases index size and can reduce the usefulness of data skipping.

### 5.2 Distributed Query Table

For a cluster, expose a distributed table to clients rather than requiring Grafana to know shard details:

```sql
CREATE TABLE observability.logs
AS observability.logs_local
ENGINE = Distributed(
    'observability_cluster',
    'observability',
    'logs_local',
    cityHash64(service_name, event_date)
);
```

The sharding expression must be tested against the actual workload. It should distribute writes reasonably and avoid concentrating high-volume services or tenants on one shard.

### 5.3 Sort Key Guidance

The sort key is the primary physical access design. It should reflect the filters used most often and retain time locality.

Good candidates usually include:

- Event date or time bucket
- Service or tenant boundary, when those are common filters
- Environment or region, when they significantly reduce scans
- A small number of stable operational dimensions
- Event time for ordered investigation

Avoid placing these directly in the sort key without evidence:

- Unbounded message text
- Request IDs with near-unique values as the first dimension
- Highly volatile attributes
- Every key from a dynamic attributes map

Use `EXPLAIN indexes = 1`, query logs, and representative data to verify whether predicates reduce the scanned granules.

### 5.4 Data-Skipping Indexes and Projections

Data-skipping indexes can help for fields that are not practical in the primary sort key, but they do not make every text query cheap. Candidate indexes should be validated with production-like distributions and query plans.

Possible candidates include:

- Bloom-filter-style indexes for exact or token-like identifiers such as trace ID
- Set indexes for small bounded categorical values
- Token or n-gram strategies for carefully selected message searches
- Projections for common aggregation or alternate access patterns

Indexes and projections add write, merge, storage, and operational cost. A query benchmark should demonstrate a meaningful reduction in scanned bytes before they are adopted.

---

## 6. Retention and Storage Tiers

A log platform should distinguish operational availability from indefinite preservation.

| Tier | Example period | Storage | Purpose |
|---|---:|---|---|
| Hot | 1-7 days | Fast local NVMe or equivalent | Interactive incident investigation |
| Warm | 7-30/90 days | Replicated lower-cost disk or object storage | Trend analysis and recurring investigations |
| Archive | 90 days to policy limit | Object storage in columnar files | Replay, audit support, legal or business retention |
| Deleted | Per policy | No retained query copy | Privacy and cost control |

Use ClickHouse TTL policies to move data between volumes or delete it, but validate that TTL movement does not overload storage or merges. Keep an archive in object storage when:

- Data must be replayed after a cluster failure.
- Retention is longer than the interactive query period.
- Legal hold or compliance policies require independent preservation.
- A future schema or parser may need to be applied again.

Retention is not complete until backups, replicas, object-storage copies, and deletion behavior have all been tested.

### 6.1 Partitioning Guidance

Partition by a coarse time unit, commonly month or day depending on volume and retention operations. Avoid creating a partition for every service, tenant, or hour unless there is a proven operational reason. Excessive partitions create metadata overhead and make merges and administration more difficult.

The right partition size depends on insert rate, retention actions, and cluster topology. Measure parts per partition and merge behavior under realistic load.

---

## 7. Query and Monitoring Tool Integration

Grafana is a suitable first monitoring and exploration interface because it can combine ClickHouse log queries with metrics, traces, annotations, and dashboards. The integration should be treated as a controlled query client, not as unrestricted database access.

### 7.1 Query Patterns

Common dashboard and investigation queries should always include a bounded time predicate:

```sql
SELECT
    event_time,
    service_name,
    severity,
    trace_id,
    message
FROM observability.logs
WHERE event_time >= $__timeFrom()
  AND event_time < $__timeTo()
  AND service_name IN (${service:sqlstring})
  AND environment = ${environment:sqlstring}
  AND severity IN ('ERROR', 'FATAL')
ORDER BY event_time DESC
LIMIT 5000;
```

Aggregated panels should avoid returning raw rows when counts or rates are sufficient:

```sql
SELECT
    toStartOfMinute(event_time) AS minute,
    service_name,
    count() AS error_count
FROM observability.logs
WHERE event_time >= $__timeFrom()
  AND event_time < $__timeTo()
  AND severity IN ('ERROR', 'FATAL')
GROUP BY minute, service_name
ORDER BY minute, service_name;
```

### 7.2 Query Governance

- Require a time range for interactive queries.
- Set maximum execution time, memory, and result-row limits for the dashboard role.
- Prefer read-only roles for Grafana.
- Use separate service accounts for ingestion, dashboards, analysts, and administration.
- Use row policies where tenant or domain isolation is required.
- Monitor slow queries, scanned bytes, memory, cancellations, and concurrent sessions.
- Avoid dashboard panels that issue many nearly identical wide scans.
- Use rollup tables for high-frequency overview panels.
- Provide a drill-down path from aggregates to bounded raw events.

### 7.3 Correlation with Metrics and Traces

Logs should carry the same resource and context attributes used by the rest of the observability platform:

```text
service.name
service.version
deployment.environment
cloud.region
host.name
k8s.namespace.name
k8s.pod.name
trace_id
span_id
request_id
```

The monitoring tool should allow an operator to move from:

```text
Alert or metric anomaly
        -> service and time window
        -> filtered logs
        -> trace ID and trace detail
        -> deployment, dependency, or runbook
```

Correlation depends more on consistent identity and timestamp semantics than on placing every signal in ClickHouse.

---

## 8. Ingestion Performance and Reliability

### 8.1 Insert Strategy

Use batched, compressed inserts. Avoid one insert per log record; that creates excessive parts and background merge pressure. The collector or buffer should group records by compatible schema and target table.

Asynchronous inserts can reduce client-side coordination overhead, but they must be configured with an explicit durability and acknowledgment policy. The system must define whether an acknowledgment means:

- accepted by the client,
- accepted into an in-memory buffer,
- persisted by ClickHouse, or
- durably recorded in an external queue.

These are different guarantees and should not be described simply as “delivered.”

### 8.2 Backpressure and Loss Policy

When ClickHouse is unavailable or too slow, the system needs an explicit policy:

| Condition | Recommended behavior |
|---|---|
| Short transient failure | Retry with bounded exponential backoff |
| Sustained database pressure | Buffer to durable queue or object storage |
| Invalid record | Send to dead-letter storage with reason |
| Oversized message | Truncate according to policy and preserve metadata |
| Buffer capacity exhausted | Apply documented sampling or loss priority |
| Schema incompatibility | Route to quarantine; alert ingestion owners |

Never allow unbounded retries to consume all collector memory or disk. The loss policy must distinguish debug logs from security, audit, or error events where business impact differs.

### 8.3 Deduplication

At-least-once delivery is usually the practical default. If duplicate events are unacceptable, generate a stable event identifier at the producer or collector and design a deduplication strategy. Exact deduplication can be expensive at very high volume; many operational systems accept occasional duplicates and make dashboards resilient through aggregation semantics.

Do not use `ReplacingMergeTree` as a general solution for ingestion duplicates without understanding eventual merge behavior, query semantics, and the cost of replacing rows.

---

## 9. Security, Privacy, and Governance

Logs frequently contain credentials, tokens, personal data, internal URLs, request bodies, and database errors. ClickHouse capacity does not remove the need for data minimization.

### 9.1 Controls

- Define an approved logging contract for each service.
- Redact secrets and authorization headers at the producer or collector boundary.
- Do not log full request or response bodies by default.
- Tokenize or hash identifiers when investigation does not require the original value.
- Encrypt traffic between producers, collectors, ClickHouse nodes, and clients.
- Encrypt disks, backups, and object-storage archives.
- Use least-privilege roles and separate operational and analytical access.
- Record access to sensitive log datasets.
- Apply row policies or separate databases for tenant isolation.
- Define deletion and legal-hold procedures before production rollout.
- Classify fields so retention and visibility can be governed consistently.

### 9.2 Schema Governance

Schema changes should be compatible and observable. Adding a field is usually easier than changing the type or meaning of an existing field. Establish ownership for:

- canonical field names and types,
- severity and status values,
- timestamp semantics,
- service and environment identity,
- sensitive-field classification,
- retention exceptions,
- parser and collector versions.

A schema registry or versioned log contract is useful when many producers are independently deployed.

---

## 10. Availability, Backup, and Disaster Recovery

### 10.1 Failure Domains

Production replicas should be distributed across failure domains such as hosts, racks, availability zones, or equivalent infrastructure. A replica on the same physical failure domain does not provide meaningful high availability.

The design should test:

- one replica unavailable,
- one shard unavailable,
- Keeper quorum loss,
- collector restart during a burst,
- network partition between collectors and ClickHouse,
- disk exhaustion,
- object-storage unavailability,
- malformed schema deployment,
- large-scale replay after recovery.

### 10.2 Recovery Objectives

Document separate objectives for:

| Data class | Example RPO | Example RTO |
|---|---:|---:|
| Debug logs | Minutes or best effort | Hours |
| Error and operational logs | Seconds to minutes | Under an hour |
| Security or audit-relevant logs | Policy-defined | Policy-defined |

Replication protects against some node failures but does not protect against bad deletes, corrupted data, operator mistakes, or logical errors. Use backups and independent object-storage copies, then regularly perform restore tests.

---

## 11. Capacity and Cost Model

A realistic capacity model should include:

```text
Raw ingest bytes per day
x compression and encoding factor
x replication factor
x hot and warm retention duration
+ merge and temporary working space
+ indexes and projections
+ metadata and backups
+ growth and failure headroom
```

Track these operational measures:

- events and bytes ingested per second,
- insert batch size and insert latency,
- rejected and dead-lettered records,
- ingestion delay from event time to query availability,
- active parts and parts per partition,
- merge backlog and merge duration,
- disk utilization and forecast exhaustion date,
- compressed and uncompressed bytes,
- query latency by percentile,
- scanned bytes per query,
- memory peaks and query cancellations,
- replica lag and distributed query failures.

Cost optimization should focus first on log quality and retention. Storing fields nobody searches, duplicating raw payloads unnecessarily, and retaining low-value debug logs for years usually costs more than query tuning can recover.

---

## 12. Alternatives and Boundary Conditions

| Option | Strength | When it may be preferable |
|---|---|---|
| ClickHouse | High-throughput analytical SQL and efficient aggregation | Structured logs, large volume, time-based exploration |
| Loki | Operational log search integrated with Grafana and label-based indexing | Cost-sensitive log workloads with bounded labels and simpler search needs |
| OpenSearch or Elasticsearch | Document search, text analysis, ecosystem for relevance queries | Fuzzy, linguistic, or document-centric search is central |
| Object storage plus query engine | Low-cost long retention and replay | Archive-first workloads with infrequent queries |
| PostgreSQL | Strong transactional semantics and simple operations at small scale | Low volume or workflow metadata, not massive raw logs |
| Cloud-native log service | Managed ingestion, retention, and integrations | The organization prioritizes reduced platform operations |

A hybrid design is often reasonable: ClickHouse for high-volume operational analysis, object storage for archive, and a separate search engine only for use cases that truly require advanced text search.

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Poor `ORDER BY` design | Slow queries and high scan cost | Capture query patterns and benchmark candidate keys |
| Unbounded dynamic fields | High memory use and poor compression | Promote stable fields; cap or filter dynamic attributes |
| Too many small inserts | Excessive parts and merge pressure | Batch and compress at the collector or queue consumer |
| Unbounded message searches | Expensive scans and poor dashboard latency | Prefer structured fields; test text indexes or use a search engine |
| Retention without tiering | Rapid storage growth | Use TTL, object storage, and documented deletion policies |
| Database used as the only buffer | Log loss during outages | Use durable buffering and a dead-letter path |
| Sharding too early | More operational and query complexity | Scale vertically and replicate before adding shards where possible |
| Sensitive data in logs | Privacy and security exposure | Redact at source and enforce access controls |
| Dashboard query explosion | Cluster saturation | Aggregate, cache, limit, and review panels |
| Replica or merge pressure | Ingestion delay and instability | Reserve capacity and alert on backlog and disk headroom |
| Treating replicas as backups | Irrecoverable logical loss | Maintain independent backups and test restores |

---

## 14. Proof of Concept and Acceptance Criteria

The proof of concept should use production-like event distributions, including realistic message sizes, cardinality, bursts, error rates, and query concurrency.

### 14.1 Test Scenarios

1. Sustained average ingestion for at least 24 hours.
2. Peak ingestion at the expected burst rate with headroom.
3. Collector and ClickHouse node restart during ingestion.
4. Network interruption and delayed replay from the durable buffer.
5. Recent error investigation by service, environment, severity, and time range.
6. Trace ID, request ID, and exact-field lookups.
7. Aggregation panels running concurrently with raw log searches.
8. Historical query against warm or archived data.
9. Replica failure and recovery.
10. Disk or object-storage capacity pressure.
11. Invalid schema and oversized message handling.
12. Restore from backup into an isolated environment.

### 14.2 Example Acceptance Criteria

| Area | Example target |
|---|---|
| Durability | No unaccounted loss during a tested collector or node outage |
| Freshness | p95 ingestion-to-query delay within the agreed operational target |
| Investigation | Common service and time-window queries meet the agreed p95 latency |
| Aggregation | Standard dashboard panels remain within the query latency budget under concurrency |
| Backpressure | Buffer growth, replay, and alerting are observable and bounded |
| Availability | Replica failure does not make the supported query path unavailable |
| Recovery | Restore and replay procedures meet the documented RTO and RPO |
| Governance | Sensitive test data is redacted and access is auditable |
| Cost | Storage and compute remain within the approved monthly envelope |

The numeric targets should be selected from the actual monitoring workflow rather than copied from a generic benchmark.

---

## 15. Recommended Adoption Path

### Phase 1: Contract and workload discovery

- Inventory log producers and current formats.
- Define required fields, sensitive fields, retention classes, and ownership.
- Capture representative ingestion and query measurements.
- Identify the first operational workflows to support.

### Phase 2: Controlled proof of concept

- Deploy a small ClickHouse topology.
- Use a collector and durable buffer where loss requirements justify it.
- Test two or three candidate sort keys with production-like data.
- Connect Grafana with read-only access and bounded queries.
- Measure ingestion delay, scan reduction, merge pressure, and cost.

### Phase 3: Production foundation

- Add replication, Keeper, backups, object-storage integration, and monitoring.
- Implement redaction, schema validation, dead-letter handling, and retention TTLs.
- Create operational dashboards for ClickHouse and the ingestion pipeline.
- Document outage, replay, deletion, and restore procedures.

### Phase 4: Scale and optimize

- Add shards only when measured storage or ingestion limits require them.
- Introduce rollups and materialized views for stable high-volume dashboards.
- Tune hot and warm tiers based on access patterns.
- Review expensive queries and producer logging quality regularly.

---

## 16. Recommendation

Proceed with ClickHouse as the primary high-volume analytical log index if the workload is primarily structured, append-only, time-bounded, and focused on operational filtering and aggregation. Use a durable collector or event buffer, not direct unprotected producer-to-database writes. Store the most frequently queried fields as typed columns, select the sort key from measured query patterns, and keep arbitrary dynamic data bounded.

The minimum production architecture should include:

- structured logging and a versioned event contract,
- OpenTelemetry Collector, Vector, or Fluent Bit at the edge,
- durable buffering for the agreed loss and recovery requirements,
- replicated ClickHouse MergeTree tables,
- object-storage archive and tested backups,
- TTL-based hot, warm, and deletion policies,
- Grafana or equivalent with read-only, resource-limited query access,
- metrics and alerts for ingestion delay, merge pressure, disk, replication, and query cost,
- redaction, least privilege, and auditable access to sensitive data.

Do not approve the final schema or cluster size from documentation alone. Approve it after the proof of concept demonstrates the required ingestion rate, query latency, recovery behavior, retention cost, and privacy controls with representative data.
