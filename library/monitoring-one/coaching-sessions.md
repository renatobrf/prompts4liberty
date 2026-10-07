# Monitoring and Observability Coaching Sessions

## Overview

This document describes the coaching sessions offered to the Service Operations team to build shared knowledge of monitoring and observability. The sessions are intended to bring operations, application, platform, and relevant vendor participants onto the same page about the products in use, current product changes, operational responsibilities, and the practical use of telemetry during incidents.

The sessions are knowledge-sharing and alignment activities. They complement, but do not replace, product documentation, implementation design, vendor support, or formal operational procedures. The technical reference for the proposed open-source stack is [Open-Source Observability Solution for Infrastructure and Applications](arch-solution-observe-open-source.md).

## Goals

- Establish a common vocabulary for monitoring, observability, metrics, logs, traces, alerts, and service-level objectives.
- Explain how telemetry supports detection, diagnosis, and service improvement.
- Share product updates and clarify their operational impact, prerequisites, and ownership.
- Make vendor interactions and product guidance visible to the whole team.
- Align teams on the observability platform direction, standards, responsibilities, and open decisions.
- Identify practical follow-up work, owners, and knowledge gaps after each session.

## Audience and Participation

The core audience is the Service Operations team. Application and platform engineers, service owners, security representatives, procurement or architecture stakeholders, and product vendors can join when a topic needs their input.

Each session should identify a facilitator, a note-taker, and the relevant subject-matter contributors. Attendees should bring operational questions, incident examples, product changes, and unresolved decisions that would benefit from a shared discussion.

## Coaching Topics

Sessions can be adapted to the team's maturity and current operational priorities. A useful progression is:

| Topic | Knowledge shared | Intended outcome |
|---|---|---|
| Monitoring and observability foundations | Signals, telemetry, instrumentation, context, and the difference between detecting symptoms and investigating causes | A consistent vocabulary and understanding of when each signal is useful |
| Product landscape and roles | OpenTelemetry SDKs, Grafana Alloy or OpenTelemetry Collector, Prometheus and exporters, Loki, Tempo, Grafana OSS, Alertmanager, and Blackbox Exporter | A shared view of how collection, storage, visualization, and notification fit together |
| Operational monitoring | Host, container, Kubernetes, database, queue, and endpoint health; dashboards; actionable alerts; and monitoring the monitoring platform | Agreement on important operational views and alert-quality expectations |
| Application telemetry | Service identity, structured logs, metrics, trace context propagation, sampling, and sensitive-data controls | Consistent telemetry that operations can use across services and environments |
| Investigation workflow | Moving from an alert or user report through metrics, traces, logs, and recent changes | A repeatable incident investigation and hand-off approach |
| Product and vendor updates | Release notes, roadmap statements, support guidance, known limitations, licensing, and compatibility | A recorded assessment of what changed and what action, if any, is needed |
| Ownership and next steps | Service ownership, retention, access, runbooks, SLOs, and action tracking | Clear responsibilities and a prioritized improvement backlog |

The proposed product list is a reference baseline, not a claim that every product has been deployed or selected. Record actual product status and decisions in the session notes.

## Product Updates

Product updates should be presented in operational terms rather than as a release-note readout. For each relevant change, capture:

- Product and component, including the version or release date when known.
- Source of the update, such as official release notes, product documentation, support case, or vendor meeting.
- What changed and whether it is generally available, in preview, deprecated, or planned.
- Impact on the team's current deployment, integrations, security posture, licensing, or operating procedures.
- Compatibility, upgrade, migration, and rollback considerations.
- Decision, owner, and target date for any follow-up; use “no action” when no change is required.

Distinguish confirmed product behavior from vendor roadmap statements, assumptions, and recommendations. Verify time-sensitive details against current official documentation before making implementation decisions.

## Vendor Interactions

Vendor engagement is a source of product and support information, not a substitute for the team's own technical and operational decisions. Use sessions to share relevant vendor guidance with all affected stakeholders and preserve its context.

For each interaction, record the vendor and participants, date, product or service, discussion purpose, questions raised, answers received, supporting links or case references, and follow-up commitments. Mark unresolved questions explicitly and assign an owner to validate them. Where advice affects architecture, security, cost, support coverage, or production operations, record the team's assessment and decision separately from the vendor's recommendation.

Do not include credentials, customer data, secrets, or sensitive incident details in these notes. Store restricted support correspondence in the organization's approved system and link to it only when readers have appropriate access.

## Putting Everyone on the Same Page

At the start of each session, confirm the service or platform scope, current product status, relevant environment, and the decision or learning goal. Explain terminology before comparing tools, and call out what is deployed, proposed, under evaluation, or out of scope.

At the end of each session, summarize:

- What the group learned or confirmed.
- Decisions made and the rationale, including any options not selected.
- Open questions, assumptions, and dependencies.
- Actions, named owners, and due dates.
- Relevant product documentation, dashboards, runbooks, support cases, and architecture references.

Share the notes with participants and affected service owners. Bring unresolved actions and product changes to the next session so the coaching series remains connected to operational work.

## Suggested Session Format

| Segment | Suggested focus |
|---|---|
| Context and objectives | Scope, current state, and desired outcome |
| Knowledge sharing | Core concept, product capability, or operational practice |
| Demonstration or case discussion | Dashboard, alert, telemetry path, incident example, or vendor guidance |
| Team discussion | Questions, service-specific concerns, and operational implications |
| Decisions and actions | Shared summary, owners, dates, and links |

Adjust the session length and balance to the topic. Prefer concrete examples from the team's services, while removing sensitive information before sharing.

## Session Record

Copy this section for each delivered session. Complete it from meeting notes and verified sources; leave unknown details marked as pending instead of inferring them.

### Session: [Title]

| Field | Details |
|---|---|
| Date and duration | [Add details] |
| Facilitator and note-taker | [Add names or roles] |
| Participants and teams | [Add participants or groups] |
| Topic and objective | [Add scope and expected outcome] |
| Products and versions discussed | [Add product/version or “not applicable”] |
| Vendor interaction or source | [Add vendor, meeting, support case, release notes, or “none”] |

**Knowledge shared**

- [Key concept, practice, demonstration, or operational lesson]

**Product updates and operational impact**

- [Verified change, source, impact, and whether action is required]

**Vendor questions and guidance**

- [Question, response, source/reference, validation status, and follow-up]

**Decisions and alignment**

- [Decision or shared understanding, rationale, and any remaining disagreement]

**Actions**

| Action | Owner | Due date | Status |
|---|---|---|---|
| [Action] | [Owner] | [Date] | [Open / in progress / done] |

**References and follow-up topic**

- [Links to documentation, dashboards, runbooks, architecture decisions, or next session topic]

## Measures of Value

Review the coaching series periodically using practical indicators such as:

- Participation across Service Operations and the teams that own monitored services.
- Completion of agreed actions and resolution of open product or vendor questions.
- Improved ability to navigate from an alert to relevant metrics, traces, logs, and runbooks.
- Better clarity of product status, ownership, escalation paths, and operational expectations.
- Feedback from participants on confidence, relevance, and remaining knowledge gaps.

Use these measures to adjust future topics. Attendance alone is not evidence that operational readiness has improved.