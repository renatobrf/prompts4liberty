# Avaliação de Arquitetura — CDC sobre Logs de Banco para Barramento ESB

Data: 2026-08-13

Visão geral
--------
Este documento avalia a arquitetura de integração por Change Data Capture (CDC), utilizando os logs de transações das bases de dados originais para detectar alterações e publicar eventos no barramento de mensageria/ESB. A solução tem como objetivo manter os dados e os sistemas consumidores atualizados sem acoplamento direto entre origem e destino, preservando consistência, rastreabilidade e baixa latência.

Escopo
------
- Validar a utilização de logs de banco para capturar INSERT, UPDATE e DELETE.
- Avaliar o uso de CDC como mecanismo de sincronização entre bases legadas e sistemas modernos.
- Definir padrões de publicação no barramento ESB, com filas e tópicos.
- Mapear requisitos de idempotência, ordering, retenção e observabilidade.
- Estabelecer critérios de segurança, resiliência e governança.

Resumo executivo
-----------------
Recomendamos a adoção de um pipeline de CDC baseado em logs de banco, conectado a um barramento de eventos com suporte a tópicos, filas e mecanismos de reforço de consumo. A solução deve ser desenhada com schemas versionados, checkpoints e deduplicação para garantir que os dados de origem sejam refletidos de forma confiável nos ambientes consumidores. A arquitetura mais adequada é híbrida: o CDC captura alterações dos bancos de origem e emite eventos para o ESB; consumidores processam, transformam e publicam o dado em sistemas downstream.

1. Objetivo da solução CDC
-------------------------
- Observar alterações em bases de dados de origem sem alterar o código de negócio dos sistemas.
- Replicar dados para outros ambientes, data stores e integrações sem depender de polling manual.
- Manter sincronização entre sistemas legados, ERP, WMS, CRM, data platforms e aplicações de integração.
- Reduzir acoplamento superficial entre sistemas, criando uma camada de eventos orientados a mudanças.

2. Conceito de CDC em bancos
----------------------------
O CDC funciona lendo registros de log de banco (binlog, WAL, redo log, transaction log, archive log) para identificar o que mudou. Esse mecanismo permite:

- identificar inserts, updates e deletes de forma incremental;
- capturar mutations sem supervisão de aplicação; 
- reduzir impacto em sistemas transacionais;
- oferecer maior confiabilidade em comparação com polling periódicos de tabela.

3. Casos de uso esperados
-------------------------
- sincronização de cadastro de clientes;
- propagação de pedidos e status;
- atualização de inventário e movimentações;
- materialização em data warehouses e analytics;
- propagação de eventos para sistemas de integração e processamento distribuído.

4. Arquitetura proposta
-----------------------
A arquitetura recomendada contém as seguintes camadas:

- Origem de dados: banco de dados transacional (MySQL, PostgreSQL, Oracle, SQL Server, Db2, etc.).
- Capturador de log: conector de CDC (Debezium, GoldenGate, Qlik, Kafka Connect, binlog reader ou conector específico do banco).
- Barramento ESB: broker de mensageria/eventos (Kafka, RabbitMQ, Pulsar) com tópicos e filas.
- Camada de transformação: normalização, enriquecimento e adaptação de contrato.
- Consumo downstream: data lake, sistemas legados, APIs, warehouses, dashboards e integrações.

Fluxo funcional:

1. O banco de origem grava transação no log.
2. O conector CDC lê a mudança do log.
3. O evento é emitido para o barramento ESB.
4. O ESB publica em temas e/ou filas.
5. Os consumidores leem os eventos e aplicam reconciliação, deduplicação e transformação.

5. Padrões de publicação no barramento
-------------------------------------
- Tópicos: para eventos do tipo publish/subscribe, quando várias aplicações precisam consumir o mesmo evento.
- Filas: para processamento assíncrono de casos puntuais, com controle de ordenação e throughput.
- Partições: importantes para ordenação e paralelismo, especialmente em Kafka.
- Enrichment: adicionar contexto de origem, schema version, traceId, correlationId.

6. Modelagem de mensagens
-------------------------
A mensagem de CDC deve conter:

- operation: INSERT, UPDATE, DELETE
- table: nome da tabela de origem
- pk: identificador primário
- before: estado anterior (quando existir)
- after: estado novo
- ts: timestamp da transação
- source: origem do evento
- schemaVersion: versão do contrato
- traceId: identificador da transação global

Exemplo de contrato:

- eventId
- sourceSystem
- sourceDatabase
- tableName
- operationType
- payload
- eventTime
- schemaVersion
- correlationId

7. Requisitos de integridade e consistência
-------------------------------------------
- Idempotência: cada consumer deve rejeitar duplicatas por eventId ou chave natural.
- Ordering: garantir ordem por chave ou partição, principalmente em eventos de estoque e pedidos.
- Exactly-once ou at-least-once: escolha por domínio. Em sistemas de estoque, at-least-once com deduplicação é mais comum.
- Checkpointing: o conector CDC deve persistir offsets de leitura dos logs para evitar perda ou duplicação.
- Reprocessamento: DLQ e replay de eventos por período.

8. Requisitos não-funcionais
----------------------------
- Latência: objetivo de propagação em segundos ou poucos minutos dependendo do volume.
- Throughput: suportar picos de alta taxa de transação, especialmente em compras e movimentações de estoque.
- Segurança: autenticação mTLS, TLS, RBAC, segregação por tópico e acesso por consumer group.
- Alta disponibilidade: cluster do conector CDC e do broker, com failover e recuperação de offset.
- Observabilidade: logs estruturados, métricas de lag, throughput, DLQ, retries e tempo de processamento.

9. Operação e observabilidade
----------------------------
- Métricas: lag do conector, eventos por segundo, filas em backlog, tempo de processamento, taxa de erro.
- Tracing distribuído: correlacionar evento de origem até processamento downstream.
- Alertas: falhas em conector, atrasos, mensagens em DLQ, perda de offset ou inconsistência em consumidores.
- Backups e recovery: manter snapshot do offset e do schema registry.

10. Estratégia de governança e schema
------------------------------------
- Versionar schemas de evento com compatibilidade controlada.
- Criar catálogo de tópicos e contratos de integração.
- Registrar ownership por domínio (vendas, estoque, financeiro, customer).
- Validar compatibilidade antes de publicar novo schema.

11. Riscos e mitigadores
-----------------------
- Risco: falha no conector CDC e perda de eventos.
  Mitigação: monitoramento rigoroso, checkpoints, reprocessamento e testes de recuperação.

- Risco: eventos duplicados por retry.
  Mitigação: eventId + deduplicação em consumidores.

- Risco: ordem de eventos incorreta em updates sequenciais.
  Mitigação: particionar por chave e garantir ordering por chave natural.

- Risco: impacto no banco de origem.
  Mitigação: usar leitura de log em modo passivo, com pouco ou nenhum impacto em produção.

- Risco: incompatibilidade de schemas entre origens e consumidores.
  Mitigação: registry, versionamento e contratos de consumo.

12. Recomendação arquitetural
---------------------------
A solução de CDC deve ser implementada como uma camada de evento orientada a mudança, com leitura de log do banco de origem e publicação em um barramento robusto. A escolha da tecnologia deve priorizar:

- conector de CDC confiável;
- broker com alta escalabilidade e retenção de eventos;
- serialização e versionamento por schema;
- consumidores idempotentes e tolerantes a falha;
- monitoramento end-to-end.

Para empresas com múltiplas bases e sistemas legados, o CDC é uma opção eficiente para manter sincronização sem alterar o código operacional das fontes. Ele reduz o risco de acoplamento direto e melhora a capacidade de integração em ambientes heterogêneos.

13. Roadmap de implantação
--------------------------
Fase 0: inventário de bases e fluxos críticos
Fase 1: POC com uma tabela crítica e um consumer downstream
Fase 2: habilitar schema registry e observabilidade
Fase 3: expansão para domínio de pedidos e estoque
Fase 4: produção com governança e replay de eventos

14. Próximos passos
-------------------
1. Definir as bases de origem e os eventos críticos.
2. Validar a capacidade do banco de origem para leitura de logs sem impacto.
3. Escolher o conector CDC e broker de mensageria.
4. Definir estratégia de idempotência e replay.
5. Validar o fluxo end-to-end com monitoramento e alertas.

Conclusão
---------
A solução de CDC usando logs de banco para publicar alterações no barramento ESB é uma abordagem sólida para manter os sistemas atualizados em tempo real ou quase real-time, com baixo acoplamento, maior escalabilidade e melhor governança de integração. A principal condição de sucesso está na definição clara de contrato, idempotência e observabilidade de toda a cadeia de eventos.
