# Template de PoC — Manhattan WMS

Objetivo
--------
Validar a viabilidade técnica e operacional da implantação do Manhattan WMS em uma malha de estoques distribuídos (2–3 centros regionais) e confirmar integrações críticas, latência de sincronização, políticas de reserva e fluxo de operações.

Escopo do PoC
--------------
- Instalar/ativar instâncias regionais do WMS em 2 centros (replicando topologia proposta).
- Integrar com um sistema ERP de teste (stub ou ambiente sandbox) para trocas de pedidos e inventário.
- Implementar mensageria assíncrona (Kafka/RabbitMQ) para eventos de movimento.
- Validar fluxos: recebimento, putaway, picking, expedição e contagem cíclica.
- Medir latência de sincronização, disponibilidade local e reconciliação de conflitos.

Critérios de sucesso (exit criteria)
-----------------------------------
- Integração ERP: envio/recebimento de mensagens com idempotência comprovada.
- Latência: operações locais concluídas dentro de SLA (picking <100ms), replicação/visão consolidada dentro de janela acordada (<30s).
- Consistência: sem oversell em testes de concorrência simulada; reconciliações automáticas detectam e corrigem divergências.
- Operação: failover regional básico validado (simular falha de uma região).
- Observabilidade: métricas, logs e tracing configurados e coletando dados úteis.

Ambiente e pré-requisitos
-------------------------
- Infra: 2–3 clusters/VMs próximos aos CDs (cloud ou on-prem) com rede entre regiões.
- Mensageria: cluster Kafka ou broker RabbitMQ de teste.
- ERP sandbox: stub que gera pedidos e consome confirmações.
- Ferramentas: Grafana, Prometheus, ELK/Logs, OpenTelemetry tracing.
- Acesso: credenciais de integração com Manhattan e documentação API.

Componentes do PoC
------------------
1. Instância Manhattan WMS por região (configuração mínima para operações)
2. Broker de mensageria (tópicos para movimentos, reservas, confirmações)
3. Adapter ERP (middleware simples que converte/valida mensagens)
4. Painéis de observabilidade e alertas
5. Scripts de carga e simulação de concorrência (simular picos e alterações de estoque)

Roteiro de atividades (2–4 semanas estimado)
-------------------------------------------
Semana 0: preparação
- Levantamento de acesso, documentação e ambiente
- Provisionamento de infra

Semana 1: integração básica
- Deploy das instâncias WMS regionais
- Conectar broker e adapter ERP
- Validar fluxo simples (pedido -> reserva -> confirmação)

Semana 2: testes funcionais e carga
- Testes de recebimento, putaway, picking e expedição
- Testes de concorrência para reservas e vendas
- Coleta de métricas e análise inicial

Semana 3: falhas, reconciliação e relatório
- Teste de failover regional e simulação de perda de rede
- Executar reconciliações; validar mitigação de conflitos
- Compilar relatório final e recomendações

Casos de teste principais (exemplos)
----------------------------------
- CT-01: Recebimento e disponibilização de estoque (tempo de ciclo)
- CT-02: Reservas concorrentes para o mesmo SKU (evitar oversell)
- CT-03: Picking e expedição com atualização de inventário central
- CT-04: Simular falha de região e validar continuidade de operações locais
- CT-05: Reconciliação pós-sincronização para divergências detectadas

Métricas a coletar
------------------
- Latência por operação (ms)
- Throughput (transações/hora)
- Queue lag do broker (ms)
- Número de conflitos e tempo para reconciliação
- Disponibilidade das instâncias regionais

Checklist de integração
-----------------------
- Endpoints/API documentados e testados
- Mensagens idempotentes e schema versionado
- Mecanismo de retry e DLQ configurado
- Autenticação e autorização (TLS, keys, RBAC)
- Mapeamento de SKUs/locais entre sistemas
- Procedimentos de rollback e scripts de reconciliação

Riscos e ações mitigadoras no PoC
--------------------------------
- Risco: falta de dados reais — Mitigação: usar dataset representativo e gerar cargas sintéticas.
- Risco: limitações de licenciamento sandbox — Mitigação: negociar acesso PoC com fornecedor ou usar trial.
- Risco: latência de rede entre regiões — Mitigação: escolher regiões/provedores próximos e medir RTT.

Entregáveis
-----------
- Ambiente PoC funcional e documentado
- Relatório de resultados com métricas, gaps e recomendações
- Plano de rollout para produção com estimativa de custos

Próximos passos
---------------
Indique se quer que eu gere: (1) roteiro detalhado de testes com passos executáveis; (2) scripts de simulação de carga; (3) checklist de integração em formato CSV/Trello.
