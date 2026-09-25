# Technical Architecture — Own Synthetic Monitoring Engine

## 1. Overview

This document describes a low-cost, low-complexity architecture for a custom synthetic monitoring engine designed to verify availability and responses from network addresses and services. The proposal is to operate as a lightweight operational observability system without depending on commercial platforms or heavy infrastructure.

The solution is intended for scenarios where the main requirement is simple and clear:

- maintain a list of addresses and endpoints;
- perform periodic availability checks;
- measure response time and failures;
- record status over a time window;
- generate basic alerts and reports;
- operate in a predictable and easy-to-maintain way.

This architecture does not aim to replace a full observability platform. Instead, it is designed as a self-owned, robust, direct, and cost-effective solution aligned with a synthetic monitoring model that can evolve as operations grow.

## 2. System objective

The system must allow the operation to monitor addresses and services of interest by verifying whether they are reachable and responding correctly. Examples of targets:

- website and API URLs
- internal service endpoints
- gateways and proxies
- hosts with specific ports
- critical services using HTTP, TCP, or ICMP protocols

The model is straightforward:

- list of destinations
- periodic check routine
- result recording
- health classification
- alert generation and operational dashboard

## 3. Main requirements

### 3.1 Functional requirements

- register a list of addresses to be monitored;
- define check intervals per target;
- verify network and service availability;
- measure response time;
- record failures, errors, and recoveries;
- generate alerts when availability drops below the threshold;
- keep minimal status history over time windows;
- provide operational visibility through simple queries.

### 3.2 Non-functional requirements

- low operational complexity;
- execution in a controlled environment with minimal external dependencies;
- easy maintenance;
- low memory and CPU consumption;
- tolerance to local failures and restarts;
- data stored in a simple, readable format;
- architecture open to evolution.

## 4. Architecture assumptions

The proposed architecture assumes:

- the system can run on a single host or a small set of agents;
- the monitor is synchronous and periodic, not event-driven;
- the list of targets is configured statically or through a configuration file;
- the main focus is availability, response time, and service failures;
- results are collected, consolidated, and visualized through a simple layer.

## 5. Solution model

The solution will be composed of four main blocks:

1. configuration manager
2. check execution engine
3. persistence and history layer
4. alerting and visualization layer

### 5.1 Configuration manager

Responsible for loading the targets to be monitored, defining intervals, timeout rules, severity, and alert policies.

Minimum structure:

- target_id
- name
- check type
- address
- port
- protocol
- interval
- timeout
- expected status
- alert_threshold
- tags
- enabled

Examples of check types:

- http
- https
- tcp
- icmp
- dns
- ssl

### 5.2 Check engine

Responsible for performing validations in a loop or according to scheduling. It reads the target list, triggers the check, and records the result.

Each check must generate a minimum record with:

- target_id
- timestamp
- status: ok, warning, critical, timeout, error
- duration_ms
- http_code
- minimal raw response
- error message
- agent_origin

The engine should remain simple:

- for each target, execute a probe routine;
- interpret the result;
- persist the outcome;
- update in-memory state;
- trigger an alert if needed.

### 5.3 Persistence and history

Data can be stored in simple files or a lightweight database, depending on scale.

Persistence options:

- CSV or JSON per target
- local SQLite
- lightweight PostgreSQL in a centralized environment
- text files with later aggregation

For a low-complexity solution, the recommended model is:

- SQLite as local or centralized database
- one table for targets
- one table for probes
- one table for alert events

This avoids dependence on a large database and provides a good balance between simplicity and organization.

### 5.4 Alerting and visualization

The alerting layer may be responsible for:

- detecting that a target is failing consecutively;
- comparing against the tolerance window;
- sending notifications via email, webhook, Slack, or a simple log;
- updating operational status in a dashboard.

Visualization can be implemented through:

- a simple HTML page;
- a terminal dashboard;
- a JSON file consumed by a lightweight frontend;
- a simple web panel in a local container.

## 6. Collection model

### 6.1 Endpoints and targets

The system must work with a list of destinations. The list may come from:

- YAML/JSON file;
- local configuration database;
- SQLite table;
- simple internal API for registration.

Each target must have check parameters appropriate to its service type.

### 6.2 Check strategy

To keep the solution simple, the engine can use a probe-per-target model with frequency rotation.

Example:

- public URL: every 2 minutes
- critical internal endpoint: every 30 seconds
- database service: every 1 minute
- router or firewall: every 5 minutes

The architecture should allow choosing the interval per target because criticality and sensitivity vary.

## 7. Main flow

1. The system reads the target list.
2. The scheduler triggers the next check.
3. The probe executes the verification against the target.
4. The result is classified into a status.
5. The event is written to history.
6. The alert rule evaluates the failure and sends a notification.
7. The dashboard updates the target state.

## 8. Probe types

### 8.1 HTTP/HTTPS

Checks:

- connection timeout
- response time
- HTTP status
- presence of expected text
- content above a minimum threshold

Useful cases:

- web portals
- authentication APIs
- public login pages
- health-check endpoints

### 8.2 TCP

Checks:

- connection to a specific port
- handshake time
- service availability

Useful cases:

- databases
- SMTP
- IMAP
- internal services

### 8.3 ICMP

Checks:

- host responds
- packet loss
- network latency

Useful cases:

- routers and devices
- critical servers
- network gateways

### 8.4 DNS

Checks:

- name resolution
- correct response
- resolution latency

## 9. Target state

Each target must have an operational state calculated from the latest results.

### 9.1 Possible states

- UP
- DOWN
- DEGRADED
- UNKNOWN
- ALERTING

### 9.2 Rule definition

A target may be considered DOWN when:

- connection failure occurs;
- timeout exceeds the defined rule;
- three consecutive checks fail; or
- unexpected HTTP status occurs for more than N attempts.

A target may be considered DEGRADED when:

- the response is slower than expected;
- a partial failure affects a relevant operation;
- the service responds, but with performance above the acceptable threshold.

## 10. Alerts

### 10.1 Alert rules

The system should support simple policies, for example:

- send an alert after 2 consecutive failures;
- repeat the warning every 10 minutes while the failure persists;
- do not alert for isolated errors on a non-critical target;
- use cooldown to avoid spam for the same target.

### 10.2 Notification channels

- email
- webhook
- local console message
- structured logs
- future integration with Slack or Teams

## 11. Suggested persistence

For low complexity, the recommended architecture is SQLite plus auxiliary files.

### 11.1 Minimum database structure

Table targets:

- id
- name
- type
- address
- port
- interval_seconds
- timeout_seconds
- alert_threshold
- enabled
- created_at

Table probes:

- id
- target_id
- ts
- status
- duration_ms
- http_code
- error_message
- response_excerpt
- agent_id

Table alerts:

- id
- target_id
- alert_type
- status
- ts_start
- ts_end
- message
- resolved

### 11.2 Advantages

- easy to operate
- no external server required
- portable
- suitable for small and medium environments
- no distributed infrastructure required

## 12. Scheduling and execution

### 12.1 Execution model

The solution can operate with a simple main loop:

- maintains the active target queue;
- schedules the next cycle per target;
- triggers the probe;
- waits for the result;
- updates the status;
- sleeps until the next interval.

### 12.2 Scheduling architecture

Possible options:

- internal loop in a single process
- scheduler with lightweight threads
- execution via cron on Unix environments
- workers per target in separate processes

For low complexity, the best option is:

- a main process with execution loop;
- multiple lightweight workers to check targets in parallel;
- a local task queue and simple synchronization.

## 13. Project structure

A minimal structure may look like this:

- app/
  - config/
  - scheduler/
  - probes/
  - storage/
  - alerts/
  - api/
  - ui/
- data/
  - targets.json
  - sqlite.db
  - logs/
- docs/
  - architecture.md

### 13.1 Suggested modules

- config_loader.py
- scheduler.py
- http_probe.py
- tcp_probe.py
- icmp_probe.py
- storage.py
- alerting.py
- dashboard.py
- runner.py

## 14. Security considerations

For a custom model, some precautions are important:

- avoid exposing secrets in logs;
- do not expose admin endpoints without authentication;
- limit output volume on failure;
- handle timeouts safely;
- separate the production environment from internal use.

## 15. Operation and maintenance

### 15.1 Model maintenance

- review the target list periodically;
- adjust timeout and frequency per service;
- handle alerts with context rather than only “down”;
- record each failure with a clear reason;
- maintain short- and medium-term histories.

### 15.2 Failure recovery

If the agent goes down:

- it should restart and continue reading the target list;
- the last cycle state should be reused or reconstructed;
- in-memory data should be persisted at short intervals;
- the process should not break the entire operation if one target fails individually.

## 16. Operational decision model

The core of the architecture does not need to be sophisticated. It can work with three simple rules:

1. check the destination;
2. classify the result;
3. decide whether the target is available or not.

This keeps the project lean, understandable, and suitable for an operation with clear goals.

## 17. Recommended architecture for a personal project

For a self-owned, low-complexity solution, the best design is:

- a single agent or a few distributed agents;
- the target list in a config file;
- simple probes in Python, Go, or shell;
- SQLite for history;
- alerts via log and webhook;
- a simple dashboard in HTML or terminal.

This architecture balances:

- simplicity;
- low cost;
- ease of maintenance;
- operational clarity;
- the ability to evolve without becoming a complex system.

## 18. Final recommendation

The most suitable architecture for a custom synthetic monitoring engine is a modular, lightweight system based on check agents, a configurable target list, simple persistence, and targeted alerts.

The solution should prioritize:

- reliability;
- ease of operation;
- minimal infrastructure dependency;
- fast and objective responses;
- the ability to evolve into a more complete monitoring system without rewriting the base.

Rather than trying to build a full observability platform from the start, the ideal approach is to create a solid synthetic monitoring base focused on availability, latency, and service failure. This makes the platform useful, inexpensive to maintain, and aligned with the actual growth of the operation.

## 19. Conclusion

A custom synthetic monitoring engine can be built in a simple and intelligent way without depending on heavy platforms. The proposed architecture combines low complexity, high clarity, and strong operational capability. The key point is to turn a list of addresses into a permanent model of checks, classification, persistence, and alerting.

With this foundation, the solution can gradually expand to include new protocols, richer alerts, and more sophisticated dashboards without losing the simplicity that makes it attractive.
