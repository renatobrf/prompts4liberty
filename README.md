# Prompts4Liberty

Prompts4Liberty is Renato Barufi's working library of software architecture assessments, solution designs, AI and prompt experiments, and small Python games. The repository mixes English and Portuguese material and favors practical artifacts over polished implementations.

## Contents

### Architecture library

The [`library/`](library/) directory contains architecture studies, service concepts, assessments, and design references organized by project:

- [`library/apliance-repair-one/`](library/apliance-repair-one/) — appliance repair use cases and assessment material
- [`library/gateway-one/`](library/gateway-one/) — payment gateway architecture, API management, data lake, integrations, security, and compliance assessments
- [`library/insurance-one/`](library/insurance-one/) — insurance architecture, cloud budget planning, fraud prevention, and the [`seguro-simples.sql`](library/insurance-one/seguro-simples.sql) data model
- [`library/logistic-one/`](library/logistic-one/) — retail logistics, WMS, ESB, CDC, fulfillment, inventory, reverse logistics, and seasonal operation studies
- [`library/open-wings/`](library/open-wings/) — cloud architecture, security planning, deployment decisions, and microservice architecture guidance

Notable starting points include:

- [Software Architecture for Insurance on AWS](library/insurance-one/software-architecture-insurance-aws-cloud.md)
- [Payment Gateway Software Architecture](library/gateway-one/gateway-pagamentos-arquitetura-software.md)
- [Kong Gateway Assessment](library/gateway-one/assessment-kong-gateway.md)
- [DB2 Historical Data Lake Assessment](library/gateway-one/assessment-datalake.md)
- [Manhattan WMS Assessment](library/logistic-one/assessment-manhattan-wms.md)
- [Scalable Microservices Architecture](library/open-wings/software-architecture.md)

### Blog and prompt material

The [`blog/`](blog/) directory contains articles and prompt-oriented explorations about AI architecture, business, weather applications, and product thinking:

- [AI Architect Specialist](blog/ai-architect-specialist.md)
- [Business One Series](blog/business-one-series.md)
- [Business Coaching](blog/business_coaching.md)
- [Weather Application](blog/app_weather.md)

### Python game experiments

- [`pygame-8bits/`](pygame-8bits/) — stock and commodity trading simulations, market prediction experiments, game instructions, and reusable game prompts
- [`pygame-16bits/`](pygame-16bits/) — the *As Aventuras da Helena* adventure games, their prompts, and [`requirements.md`](pygame-16bits/requirements.md)

The 8-bit projects include [`market_game.py`](pygame-8bits/market_game.py), [`commodities-trader-v2.py`](pygame-8bits/commodities-trader-v2.py), [`stock-prediction.py`](pygame-8bits/stock-prediction.py), and [`trading-simulator.py`](pygame-8bits/trading-simulator.py). The game configuration is in [`game_config.json`](pygame-8bits/game_config.json).

## How to use this repository

Browse the project folders for reference material, architecture discussion starters, and prompt examples. The Python files are exploratory games and simulations; inspect each folder's documentation and requirements before running them.

## Author

[Renato Barufi](https://www.linkedin.com/in/renato-barufi-a2a7ab130/) — Solution Architect and AI Specialist

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for ways to provide feedback, suggest improvements, or collaborate on new material.
