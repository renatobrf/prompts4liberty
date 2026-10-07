# Exploring Heroku: Features, Capabilities, and What to Try

## Overview

Heroku is a Platform as a Service (PaaS) for building, deploying, and operating applications without managing every layer of the underlying infrastructure. Instead of starting with virtual machines, operating-system images, and deployment scripts, a team can focus on the application, choose a deployment workflow, and run its processes on Heroku-managed compute called dynos.

That simplicity is Heroku's central idea, but the platform is more than a place to push code. It includes deployment workflows, managed data services, operational tools, integrations, and options for isolated networking. Understanding how these pieces fit together is a useful way to evaluate where Heroku can help and what you should explore before choosing it for a real service.

## How the Platform Works

An application runs as one or more process types. A `web` process serves requests, a `worker` process handles asynchronous work, and one-off dynos can run tasks such as migrations or administrative commands. The Heroku process model lets teams scale the number or size of dynos to match the workload.

For source-based deployments, buildpacks detect an application's language and dependencies and produce a deployable artifact. Heroku supports languages including Node.js, Ruby, Java, Python, PHP, Go, Scala, Clojure, and .NET. Teams can also use custom buildpacks where supported, and some deployment paths support container images.

Configuration is kept outside application code using config vars, which are exposed to the running application as environment variables. This makes it possible to use the same code with different settings in development, staging, and production. Treat config vars as sensitive: control access, avoid printing values to logs, and verify how the selected build method handles build-time configuration.

## Features Worth Exploring

### 1. App Runtime and Dynos

Explore the process model, dyno sizes, restart behavior, scaling controls, and the differences between web, worker, and one-off processes. A useful experiment is to deploy a small application with both a request-serving process and a background worker, then observe how each is managed and scaled.

Dyno filesystems are ephemeral. Files written while a dyno is running should be treated as temporary; persistent application data belongs in a database or external object store. Horizontal scaling also depends on dyno type and plan, so confirm the limits and pricing for the tier you intend to use.

### 2. Build and Deployment Choices

Heroku offers Git-based deployment, GitHub integration, and generation-specific container/build workflows. GitHub integration can deploy selected branches and can wait for external CI checks before deploying. The Heroku CLI and Dashboard provide ways to manage deployments, releases, configuration, and app resources.

The platform currently has two generations to understand:

| Generation | What to know |
|---|---|
| Cedar | The established platform generation, with classic buildpacks and its existing ecosystem of capabilities. Cloud Native Buildpacks are also available for Cedar apps. |
| Fir | The newer generation, built around Cloud Native Buildpacks, modern cloud-native infrastructure, and OpenTelemetry-based telemetry. Some Cedar features are not yet available on Fir, while Fir also introduces capabilities that are specific to the newer generation. |

Do not assume that a deployment method or feature works identically on both generations. Check the current generation comparison before planning a new app or migration, especially if you depend on a custom classic buildpack, Docker-based build, monorepo build, autoscaling, or a particular networking feature.

### 3. Pipelines and Review Apps

Pipelines group apps into delivery stages such as development, review, staging, and production. Teams can test a change in staging and promote the same build artifact to production, reducing the risk that production runs an artifact different from the one that was tested.

Review Apps create temporary Heroku apps for pull requests so reviewers can exercise a change in a running environment. They are useful for integration testing and stakeholder review, but the dynos and add-ons used by these temporary apps can incur costs. Review App configuration and availability also depend on the repository and platform setup.

### 4. Managed Data and Add-ons

Heroku's data offerings include Heroku Postgres, Heroku Key-Value Store, and Apache Kafka on Heroku. Add-ons from Heroku Elements extend applications with services such as logging, monitoring, caching, and other integrations. This ecosystem can reduce the amount of infrastructure a team must operate itself.

Before selecting a service, compare its plans, regional availability, backup and recovery behavior, high-availability options, limits, support model, and exit or migration path. “Managed” reduces operational work; it does not remove the need to understand data lifecycle, capacity, and cost.

### 5. Operations, Logs, and Metrics

Heroku provides app and platform logs, application metrics, deployment and configuration events, and alerting capabilities. The CLI can stream logs for troubleshooting, while the Dashboard exposes app activity and available metrics. Some metrics, alerts, and autoscaling behavior depend on dyno tier and platform generation.

There is an important observability distinction between generations. Cedar logging uses the existing log routing model, with limited built-in history unless logs are sent to a persistent destination. Fir uses OpenTelemetry signals and telemetry drains for exporting logs and other telemetry; Fir does not have log history in the same way. Heroku's application metrics can help diagnose runtime health, but teams with broader retention, cross-service correlation, distributed tracing, or custom SLO needs should evaluate an external observability backend and the supported export path for their generation.

Autoscaling is another feature to investigate rather than assume. Its availability is limited by dyno tier and generation, and it cannot fix a database or downstream service bottleneck. Load testing, application metrics, and capacity planning remain necessary.

### 6. Networking and Enterprise Controls

Private Spaces provide dedicated environments with network isolation for apps and certain add-ons. Depending on the generation and configuration, teams can explore stable outbound IPs, trusted IP ranges, private connectivity, and deployment controls. Heroku also offers team and enterprise capabilities and products for specific security and compliance needs.

These capabilities are not a substitute for a requirements review. Confirm the exact certification scope, networking behavior, region, data-residency implications, identity controls, and available features for the specific space generation and product plan.

### 7. Salesforce and AI Integrations

Heroku's Salesforce relationship is visible in integrations such as Heroku Connect and Heroku AppLink, which can connect applications with Salesforce data and workflows. Heroku also presents AI-oriented capabilities, including Managed Inference and Agents, MCP-related tooling, and pgvector for Heroku Postgres.

These are good areas to explore when an application needs Salesforce connectivity or AI features. Check the current documentation for availability, supported models and frameworks, data handling, limits, pricing, and regional or generation requirements before treating a capability as a production dependency.

## A Practical Exploration Path

1. Deploy a small supported-language application and inspect the build output, release history, and process formation.
2. Add a worker process and a one-off task to understand the process model.
3. Set separate config vars for development and production, and confirm secrets are not exposed in source control or logs.
4. Connect a GitHub repository, require CI checks, and try a Review App for a pull request.
5. Create a Pipeline with staging and production apps, then learn how artifact promotion works.
6. Provision a managed data service in a non-production app and inspect backups, metrics, limits, and the cost model.
7. Review runtime logs and application metrics, then test exporting telemetry to an external observability platform.
8. Compare Cedar and Fir against your actual application dependencies before selecting a generation or planning a migration.
9. For enterprise workloads, evaluate Private Spaces, access controls, networking, compliance scope, and operational responsibilities.

For each experiment, record what is managed by Heroku, what remains the application's responsibility, which plan or generation is required, and how the feature affects cost and support operations.

## Where Heroku Fits

Heroku is worth considering when a team values a short path from code to a running application, managed runtimes, straightforward app operations, and integrated delivery workflows. It can be especially useful for prototypes, APIs, internal services, and product teams that want to minimize routine infrastructure work.

The trade-off is abstraction. Teams give up some low-level control and must work within platform conventions, product availability, runtime generations, and service limits. For workloads with unusual networking, specialized compute, strict portability requirements, or substantial platform engineering needs, compare Heroku with infrastructure platforms that provide more direct control.

The best evaluation is a small, representative workload: deploy it, observe it, scale it, test a failure, and calculate its real operating cost. That exercise will reveal whether Heroku's developer experience matches the needs of the application and the team.

## Official Resources

- [Heroku Platform](https://www.heroku.com/platform)
- [Heroku Dev Center](https://devcenter.heroku.com/)
- [Heroku Generations: Cedar and Fir](https://devcenter.heroku.com/articles/generations)
- [Dynos](https://devcenter.heroku.com/articles/dynos)
- [Buildpacks](https://devcenter.heroku.com/articles/buildpacks)
- [Pipelines](https://devcenter.heroku.com/articles/pipelines)
- [GitHub Integration](https://devcenter.heroku.com/articles/github-integration)
- [Heroku Logging](https://devcenter.heroku.com/articles/logging)
- [Application Metrics](https://devcenter.heroku.com/articles/metrics)
- [Heroku Private Spaces](https://devcenter.heroku.com/articles/private-spaces)
- [Heroku Managed Data Services](https://www.heroku.com/managed-data-services/)
- [Heroku AI](https://www.heroku.com/ai/)

*Feature availability, pricing, and product capabilities change. Verify current Heroku documentation for the app's platform generation, region, and plan before implementation.*