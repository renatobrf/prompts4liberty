# Avaliação de Arquitetura — Manhattan WMS

Data: 2026-08-13

Visão geral
--------
Este documento avalia a viabilidade, riscos e recomendações para a implantação do sistema de gestão de armazéns (WMS) Manhattan em uma malha de estoques distribuídos em rede nacional. O fornecedor oferece soluções de execução de cadeia de suprimentos (ver: https://www.manh.com/pt-br/solucoes/execucao-de-cadeia-de-suprimentos/sistema-de-gestao-de-armazem).

Escopo
------
- Avaliar opções de arquitetura (cloud, on-premise, híbrida)
- Sincronização e consistência entre centros distribuídos
- Integrações críticas (ERP, TMS, carriers, e-commerce)
- Requisitos não-funcionais: disponibilidade, performance, segurança
- Operação, monitoramento, backups e plano de recuperação

Resumo executivo
-----------------
Recomendamos uma implantação híbrida com instâncias regionais próximas aos centros de distribuição para latência e resiliência, combinada com um plano central de coordenação/masters para visões globais de inventário. A solução deve contemplar integração padrão com ERP/TMS via APIs/mensageria e garantias claras sobre latência de sincronização e resolução de conflitos.

1. Visão do Manhattan WMS
------------------------
- Produto comercialmente maduro, com módulos para execução de armazém, orquestração de tarefas, roteirização interna e interfaces para automação.
- Fornece opções de implantação em nuvem e on-premise; confirmar com o fornecedor os detalhes de arquitetura e SLA.

2. Requisitos iniciais do projeto
--------------------------------
- Functional: recebimento, localização, picking, packing, cross-dock, inventário cíclico, lotes/validades.
- Integrações: ERP (master de pedidos e cadastro), TMS, carriers, marketplaces, sistemas de automação (AGV/ASRS).
- Dados: mestre de SKUs, níveis de estoque por local físico, movimentos em tempo real, eventos de contagem.

3. Considerações para malha de estoques distribuídos
---------------------------------------------------
- Topologia: múltiplas instâncias regionais que autoritativamente gerenciam estoques locais; um plano de coordenação central para visões consolidada.
- Consistência: usar modelo eventual-consistente para operações locais críticas e reconciliar com o master central; definir políticas para reservas de estoque (lock local vs. central) para evitar oversell.
- Sincronização: mensageria assíncrona (Kafka/RabbitMQ/SQS) para eventos de movimento; APIs síncronas somente para operações que exigem confirmação imediata.
- Latência: definir SLAs aceitáveis por caso de uso (e.g., picking local <100ms; visões consolidadas <5s-30s dependendo do cenário).
- Conflitos: políticas claras de resolução (timestamp, origem preferencial, last-writer-wins) e rotina de reconciliação diária.

4. Arquitetura proposta (alto nível)
----------------------------------
- Camadas:
  - Apresentação: UI web/terminal móvel
  - Aplicação: instâncias Manhattan WMS por região (containerizadas ou VMs gerenciadas)
  - Integração: barramento de eventos (Kafka/Message Broker) e APIs REST/gRPC
  - Dados: banco local por instalação + replicação/CDC para data lake central
  - Coordenação Central: serviço agregador para visões globais, regras de alocação cross-site
- Implantação:
  - Regiões: clusters regionais em provedores ou DCs locais próximos aos centros de distribuição
  - Central: instância logical/geo-redundante para reporting, consolidação e orquestração global

5. Integrações e fluxos de dados
--------------------------------
- ERP: troca de pedidos, confirmações de reserva, inventário mestre via APIs/B2B (preferir mensagens idempotentes)
- TMS/Carriers: eventos de expedição e rastreamento
- E-commerce/Marketplaces: sincronização de disponibilidade (cuidado com latência)
- Automação: interfaces determinísticas (commands/telemetry) para gateways de automação

6. Requisitos não-funcionais
----------------------------
- Disponibilidade: alvo >= 99.9% para operações críticas; arquitetura com failover regional
- Escalabilidade: auto-scaling de componentes stateless; partição de carga por região/centro
- Performance: medir RPS e latência em picos; sizing inicial baseado em transações/hora por CD
- Segurança: TLS em trânsito, criptografia em repouso, IAM/segurança por perímetro e RBAC no WMS
- Conformidade: auditoria de movimentos, logs imutáveis para inventário e rastreabilidade

7. Operação e observabilidade
-----------------------------
- Monitoramento: métricas (latência, erros, queue-lag), dashboards (Grafana), alertas (PagerDuty)
- Logs e tracing distribuído (OpenTelemetry)
- Backups: snapshots consistentes do banco local; política de retention e testes regulares de restore
- DR: failover regional documentado e testes semestrais
- Ciclo de upgrades: janelas de manutenção, estratégia blue/green ou canary para minimizar impacto

8. Riscos e mitigação
---------------------
- Risco: inconsistência de estoque entre sites — Mitigação: regras de reserva local, reconciliador, reconciliações periódicas.
- Risco: latência demasiada impactando vendas online — Mitigação: cache local de disponibilidade, política de reserva imediata.
- Risco: integração complexa com ERP legado — Mitigação: adaptar camada de integração, usar adaptadores e testes de contrato.
- Risco: custos de licenciamento e infra inesperados — Mitigação: negociações com fornecedor, protótipo PoC para estimativas.

9. Custos e licenciamento
-------------------------
- Mapear modelo de licenciamento Manhattan (por módulo, por transação, por instalação) e custos de infra.
- Considerar custos adicionais: integração, engenharia, rede (latência e transferência), suporte e formação.

10. Recomendações e próximos passos
----------------------------------
1. Executar PoC em um conjunto de 2-3 centros regionais com tráfego real para validar latência, sincronização e integrações.
2. Confirmar com Manhattan os modelos de implantação suportados, SLAs, opções de multi-site e APIs documentadas.
3. Projetar e implementar camada de mensageria (Kafka/RabbitMQ) para eventos de movimento e integração idempotente.
4. Definir políticas de reserva/consistência e planos de reconciliação automática/manual.
5. Preparar testes de DR e planos de rollback;
6. Avaliar custo total TCO com fornecedor e provedores de nuvem/DC.

Anexos / Referências
--------------------
- Página do fornecedor: https://www.manh.com/pt-br/solucoes/execucao-de-cadeia-de-suprimentos/sistema-de-gestao-de-armazem

Contato
-------
Para continuar, revisar este documento e indique se deseja que eu gere um template de PoC, roteiro de testes e checklist de integração.
