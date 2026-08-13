# Avaliação de Arquitetura — Barramento ESB de Mensageria (Assíncrono)

Data: 2026-08-13

Visão geral
--------
Este documento avalia a proposta de implementar um barramento de integração (ESB baseado em mensageria) para conectar sistemas legados e produtos, oferecendo uma camada assíncrona de comunicação com postagens e consumidores, suportando interoperabilidade, desacoplamento e resiliência.

Escopo
------
- Avaliar topologias possíveis (centralizado, federado, híbrido)
- Definir padrões de mensagens, schemas e contratos (JSON/Avro/Protobuf)
- Mapeamento de adaptadores para sistemas legados (JMS, FTP, SOAP, DB polling)
- Requisitos não-funcionais: throughput, latência, SLA, segurança
- Operação: monitoramento, observabilidade, DLQ, retries, idempotência

Resumo executivo
-----------------
Recomendamos um modelo federado com brokers regionais e um backbone central para roteamento e transformação de mensagens. Utilizar um broker moderno (Kafka, RabbitMQ ou Pulsar) com camada de integração (KStreams/Connect, Kafka Connect, Camel) para adaptadores. Priorizar contratos versionados, mensagens idempotentes e estratégias de reconciliação para legados.

1. Objetivos do barramento
-------------------------
- Desacoplar produtores e consumidores, permitindo evolução independente.
- Habilitar padrões pub/sub e filas point-to-point para diferentes casos de uso.
- Fornecer garantia de entrega (at-least-once/at-most-once/exactly-once quando aplicável).
- Centralizar observabilidade e gestão de contratos de integração.

2. Topologias e padrões recomendados
----------------------------------
- Federado: brokers regionais responsáveis por tráfego local; backbone replicado para comunicações cross-region.
- Centralizado (único broker) para organizações menores, evitar single-point-of-failure com clusters redundantes.
- Padrões: pub/sub, command queue, event sourcing, change-data-capture (CDC) para sincronização de dados.

3. Modelagem de mensagens e contratos
------------------------------------
- Use schemas versionados (Avro/Protobuf/JSON Schema) e registre em um Schema Registry.
- Mensagens event-driven com metadados: `eventId`, `timestamp`, `source`, `version`, `correlationId`, `traceId`.
- Contratos claros com exemplos e testes de compatibilidade (consumer-driven contract tests).

4. Conectores e adaptadores para legados
---------------------------------------
- Adapter patterns: connector-specific microservices (JDBC poller, FTP ingestor, SOAP-to-event gateway, JMS bridge).
- Use frameworks como Apache Camel, Kafka Connect ou Spring Integration para reduzir código customizado.
- Tratamento de transformação e enriquecimento: realizar em stream processors ou ESB transform layer.

5. Garantias e semânticas de entrega
-----------------------------------
- Definir por caso de uso: inventory events => idempotent, at-least-once com dedup; financial events => exactly-once se suportado.
- Dead-letter queues para mensagens com falha; políticas de retry expondo causa raiz.
- Idempotência: incorporar `eventId` e store de deduplicação para operações side-effect.

6. Requisitos não-funcionais
----------------------------
- Throughput: sizing baseado em picos diários e sazonalidade; provisionamento elástico.
- Latência: SLAs por tipo de evento (comando síncrono vs evento de baixa prioridade).
- Segurança: TLS, mTLS, ACLs por tópico, criptografia em repouso, RBAC, auditoria.
- Resiliência: replicação cross-region, retenção de logs, compactação de tópicos críticos.

7. Observabilidade e operação
-----------------------------
- Métricas: throughput, consumer lag, errors, retries, DLQ size
- Tracing distribuído (OpenTelemetry), logs estruturados, dashboards e alertas
- Gestão de esquema: compatibilidade e rollback de schemas
- Playbooks operacionais: onboarding de consumers/producers, incident response

8. Segurança e conformidade
--------------------------
- Autenticação e autorização centralizadas (OAuth2, mTLS)
- Monitoramento de acesso e auditoria por tópico/evento
- Políticas de retenção e GDPR/Regulatory compliance para dados sensíveis

9. Riscos e mitigação
---------------------
- Risco: latência entre legados e consumers — Mitigação: adaptar com caches e retries.
- Risco: perda de mensagens em picos — Mitigação: escalonamento automático, backpressure, DLQ.
- Risco: complexidade de transformações — Mitigação: usar pipeline de transformação centralizada com testes e CI.

10. Roadmap de implantação (fases)
---------------------------------
Fase 0: Discovery e inventário de integrações
Fase 1: Prova de conceito com 2-3 integrações críticas
Fase 2: Pilot com regionalização e monitoramento
Fase 3: Rollout gradual por domínio e cutover

11. Requisitos de governança
----------------------------
- Registro de tópicos, owners, SLAs e times responsáveis
- Política de versionamento de schema e deprecação
- Processos para onboarding e offboarding de sistemas

12. Recomendações e próximos passos
----------------------------------
1. Realizar inventário completo de integrações e pontos de dor dos legados.
2. Escolher tecnologia de broker (Kafka/Pulsar para escala; RabbitMQ para casos de fila intensiva) e tecnologia de integração (Camel/Kafka Connect).
3. Projetar PoC focado em CDC (Change Data Capture) para sincronização de dados entre DB legado e tópicos do barramento.
4. Implementar schema registry, pipelines de testes de contratos e observabilidade básica.
5. Treinar equipes de integração em padrões de mensagens e melhores práticas.

Referências
----------
- Apache Kafka, Kafka Connect, Kafka Streams
- Apache Pulsar
- RabbitMQ
- Apache Camel

Contato
-------
Se quiser, gero um template de PoC com roteiro de testes e checklist de integração para este barramento.
