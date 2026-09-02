# Prompts4Liberty

Prompts4Liberty is Renato Barufi's working library of software architecture assessments, solution designs, modernization plans, AI explorations, and prompt experiments. It favors practical artifacts and discussion starters over polished implementations. The repository contains material in English and Portuguese.

## Contents

### Architecture library

The [`library/`](library/) directory contains architecture studies, service concepts, assessments, data models, and design references organized by project:

- [`library/apliance-repair-one/`](library/apliance-repair-one/) - appliance repair use cases, architecture assessment material, and a SQL schema
- [`library/gateway-one/`](library/gateway-one/) - payment gateway architecture, API management, data lake, legacy export, hybrid cloud modernization, integrations, and security
- [`library/insurance-one/`](library/insurance-one/) - insurance architecture, AWS budget planning, fraud prevention, service design, and the [`seguro-simples.sql`](library/insurance-one/seguro-simples.sql) data model
- [`library/open-wings/`](library/open-wings/) - cloud architecture, security planning, technology decisions, AWS budgeting, and scalable microservice guidance
- [`library/retail-one/`](library/retail-one/) - retail operations, WMS, ESB, CDC, DDD, fulfillment, inventory, reverse logistics, and seasonal planning
- [`library/university-one/`](library/university-one/) - university solution and data architecture studies, context material, and an HTML artifact

Useful starting points include:

- [Software Architecture for Insurance on AWS](library/insurance-one/software-architecture-insurance-aws-cloud.md)
- [Payment Gateway Software Architecture](library/gateway-one/gateway-pagamentos-arquitetura-software.md)
- [Kong Gateway Assessment](library/gateway-one/assessment-kong-gateway.md)
- [DB2 Historical Data Lake Assessment](library/gateway-one/assessment-datalake.md)
- [Manhattan WMS Assessment](library/retail-one/assessment-manhattan-wms.md)
- [Scalable Microservices Architecture](library/open-wings/software-architecture.md)
- [University Solution Architecture](library/university-one/solution-architecture-1st-analysis.md)

The retail collection also includes detailed logistics service concepts in [`library/retail-one/logistics/`](library/retail-one/logistics/), covering stock balancing, fulfillment, regional inventory, pickup, reverse logistics, and delivery operations.

### Blog and prompt material

The [`blog/`](blog/) directory contains articles and prompt-oriented explorations about AI architecture, business, weather applications, and product thinking:

- [AI Architect Specialist](blog/ai-architect-specialist.md)
- [Business One Series](blog/business-one-series.md)
- [Business Coaching](blog/business_coaching.md)
- [Weather Application](blog/app_weather.md)

## How to use this repository

Browse the project folders for reference material, architecture discussion starters, service concepts, data models, and prompt examples. Each document stands on its own, so start with the project directory or one of the recommended entry points above.

## Author

[Renato Barufi](https://www.linkedin.com/in/renato-barufi-a2a7ab130/) - Solution Architect and AI Specialist

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for ways to provide feedback, suggest improvements, or collaborate on new material.
