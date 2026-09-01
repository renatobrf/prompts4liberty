# Plano de Arquitetura para Datas Sazonais do Varejo

## Black Friday

**Status:** proposta de arquitetura e operação  
**Data de referência:** 2026-08-20  
**Escopo:** canais digitais, lojas físicas, marketplace, logística e sistemas corporativos  
**Evento-alvo:** Black Friday e demais períodos de pico do varejo

## 1. Objetivo

Definir a arquitetura, os controles e o procedimento operacional para concentrar a capacidade computacional disponível no ambiente de produção durante uma data sazonal crítica, como a Black Friday.

Durante a janela do evento, os ambientes não produtivos elegíveis serão desligados ou reduzidos ao mínimo operacional. A capacidade liberada será direcionada ao ambiente de produção para suportar o aumento de tráfego, pedidos, consultas de estoque, pagamentos, integrações logísticas e processamento de eventos.

O plano deve aumentar a capacidade de atendimento sem comprometer:

- integridade de pedidos, pagamentos e estoque;
- continuidade dos sistemas legados em IBM mainframe e IBM i/AS400;
- processamento do Apache Kafka e do Kafka Connect/CDC;
- segurança, rastreabilidade e requisitos de auditoria;
- capacidade de recuperação após o evento.

## 2. Princípios arquiteturais

1. **Produção é a prioridade durante o evento:** recursos ociosos de desenvolvimento, teste e homologação podem ser realocados, desde que não sejam necessários para suporte ou recuperação.
2. **Desligar não significa apagar:** ambientes não produtivos devem ser parados de forma reversível, mantendo configurações, imagens, volumes e dados necessários para sua retomada.
3. **Dados produtivos não serão usados indiscriminadamente:** ambientes não produtivos não devem receber dados de produção sem mascaramento e autorização formal.
4. **Capacidade não substitui isolamento:** a consolidação de workloads não pode eliminar limites de CPU, memória, rede, armazenamento ou segurança entre serviços.
5. **Mudanças congeladas:** durante a janela crítica, somente mudanças emergenciais, previamente aprovadas, serão implantadas.
6. **Degradação controlada:** funcionalidades secundárias devem ser desabilitadas ou colocadas em fila antes que as capacidades críticas sejam afetadas.
7. **Rollback sempre disponível:** toda mudança de capacidade deve ter uma forma documentada de reversão e um responsável nomeado.

## 3. Escopo tecnológico atual

### 3.1 Infraestrutura e sistemas corporativos

- IBM mainframe com DB2 e COBOL.
- IBM i/AS400 com DB2 e COBOL.
- Servidores Linux on-premises com DB2, PostgreSQL e servidores web.
- Servidores Linux em cloud com PostgreSQL e servidores web.
- Apache Kafka como barramento de eventos/ESB.
- Apache Kafka Connect para CDC.

### 3.2 Plataforma de microsserviços

- Clusters Kubernetes on-premises e em cloud.
- Imagens Docker armazenadas em repositório privado.
- MongoDB para dados não relacionais dos front-ends.
- Node.js e Go para front-ends e APIs de borda.
- Python e Java para back-ends e serviços de negócio.

### 3.3 Canais e capacidades de negócio

- B2B.
- E-commerce.
- Lojas físicas.
- Logística e fulfillment.
- Marketplace.
- CDC/crediário.

### 3.4 Serviços de borda

- API Gateway para centralização de chamadas, autenticação, autorização, limitação de tráfego e auditoria.
- Akamai para cache e distribuição de páginas e conteúdo elegível.

## 4. Capacidades críticas durante a Black Friday

| Prioridade | Capacidade | Comportamento esperado |
| --- | --- | --- |
| P0 | Acesso aos canais | Disponível com proteção contra abuso e sobrecarga |
| P0 | Catálogo e preço | Disponível; cache preferencial para consultas de leitura |
| P0 | Estoque e reserva | Consistente, com prevenção de overselling |
| P0 | Carrinho e checkout | Disponível, com filas e timeouts controlados |
| P0 | Pagamento e antifraude | Processamento seguro e idempotente |
| P0 | Criação e atualização de pedidos | Persistência durável e reconciliação posterior |
| P0 | Integração com logística | Eventos e ordens processados sem perda |
| P1 | Rastreamento de pedidos | Pode operar com atraso controlado e processamento assíncrono |
| P1 | Marketplace e parceiros | Limites de consumo por parceiro e prioridade por contrato |
| P2 | Relatórios não operacionais | Pode ser adiado para depois da janela |
| P2 | Funcionalidades administrativas | Pode ser reduzido ou temporariamente indisponível |
| P2 | Ambientes de desenvolvimento e testes | Desligados, exceto os componentes aprovados para suporte |

## 5. Modelo de capacidade

A capacidade liberada dos ambientes não produtivos será direcionada para produção em três camadas:

1. **Escala de aplicação:** aumento horizontal de réplicas dos serviços stateless em Kubernetes e dos servidores web.
2. **Escala de plataforma:** expansão de node pools, workers, limites de pods, ingress controllers, conexões e filas, conforme os limites previamente testados.
3. **Escala de dados e integração:** aumento controlado de recursos para PostgreSQL, MongoDB, Kafka, Kafka Connect e componentes de cache, respeitando IOPS, conexões, partições, retenção e capacidade de replicação.

A capacidade dos sistemas IBM mainframe e IBM i/AS400 não deve ser presumida como livremente redistribuível. Para esses sistemas, o plano deve usar limites de transação, priorização de jobs, janelas de processamento e monitoramento de consumo definidos com os respectivos owners.

### 5.1 Reserva de capacidade

Mesmo durante o pico, deve ser preservada uma reserva mínima para:

- observabilidade e ferramentas de operação;
- bastion hosts e acesso administrativo emergencial;
- pipelines de produção e registro de imagens;
- replicação, backup e recuperação;
- processamento de incidentes e automações de rollback;
- serviços de segurança, DNS, identidade e certificados.

Nenhum node pool deve operar permanentemente no limite nominal. Os valores de utilização, headroom e quantidade de réplicas serão definidos no ensaio de capacidade e registrados no runbook do evento.

## 6. Estratégia por ambiente

### 6.1 Desenvolvimento, teste e homologação

Antes da janela de congelamento:

- interromper pipelines automáticos que possam publicar alterações;
- finalizar ou cancelar execuções não essenciais;
- exportar configurações, manifestos e versões implantadas;
- validar que não existem integrações ativas com produção;
- realizar backup dos dados necessários à retomada;
- desligar VMs, servidores web, workers e node pools elegíveis;
- suspender jobs agendados, consumidores Kafka e conectores não produtivos;
- preservar os artefatos no repositório privado de imagens.

Devem permanecer ativos somente os componentes explicitamente aprovados para suporte, segurança, auditoria, validação ou recuperação.

### 6.2 Produção

A promoção da capacidade deve ser feita em ondas, com validação após cada onda:

1. serviços de borda, CDN/Akamai, API Gateway e ingress;
2. front-ends Node.js/Go e APIs de leitura;
3. carrinho, checkout, pagamento e antifraude;
4. serviços de pedido, estoque e reserva;
5. serviços de logística, fulfillment e integrações;
6. consumidores Kafka, Kafka Connect/CDC e workers assíncronos;
7. bancos de dados, cache e armazenamento, somente quando os testes confirmarem a necessidade.

A expansão deve ser automatizada por infraestrutura como código e políticas versionadas. Alterações manuais emergenciais devem ser registradas e reconciliadas posteriormente no código-fonte da infraestrutura.

### 6.3 Sistemas legados

Mainframe, IBM i/AS400, DB2 e integrações legadas permanecem em operação conforme seus acordos de capacidade. O foco é proteger esses sistemas de tempestades de chamadas:

- aplicar rate limit no API Gateway;
- usar cache para consultas que não exigem leitura em tempo real;
- agrupar ou assíncronizar chamadas quando o contrato permitir;
- controlar concorrência de jobs e consumidores;
- aplicar backpressure e filas duráveis;
- monitorar filas, locks, tempo de resposta, uso de CPU e jobs atrasados;
- manter procedimentos de reconciliação para falhas ou atrasos.

## 7. Kafka e CDC

O cluster Kafka deve ser tratado como componente P0 de integração. Antes do evento, devem ser validados:

- capacidade de disco, retenção e taxa de crescimento por tópico;
- número de partições e distribuição dos líderes;
- replication factor e estado das réplicas;
- consumer lag por grupo crítico;
- capacidade de rede e throughput de produtores/consumidores;
- estado dos conectores Kafka Connect e dos offsets;
- comportamento de reprocessamento e idempotência;
- alertas para mensagens rejeitadas, DLQ e falhas de serialização.

Consumidores não essenciais devem ser pausados ou reduzidos. Consumidores de pedido, estoque, pagamento e logística permanecem ativos com capacidade dimensionada e limites de concorrência testados. Nenhum tópico crítico será apagado ou terá retenção reduzida durante o evento sem aprovação de emergência.

## 8. Dados, consistência e recuperação

- Executar backups e validar restauração antes da janela crítica.
- Confirmar replicação do PostgreSQL, MongoDB e DB2 conforme o desenho de cada sistema.
- Garantir idempotência para criação de pedido, pagamento, reserva e publicação de eventos.
- Usar correlation ID e chave de negócio para rastrear uma operação de ponta a ponta.
- Evitar operações de manutenção pesada, migrações de schema e reindexações durante o congelamento.
- Definir a fonte de verdade para preço, estoque, pedido e pagamento.
- Executar reconciliação de pedidos, pagamentos, estoque e eventos após o pico.

## 9. Segurança e governança

A redução de ambientes não produtivos não deve reduzir os controles de segurança. Permanecem obrigatórios:

- autenticação forte e RBAC;
- segregação de redes e namespaces;
- TLS e gestão de certificados;
- WAF, rate limit, proteção contra bots e regras no API Gateway;
- secrets armazenados em mecanismo apropriado, sem valores em manifestos;
- logs de auditoria e trilhas de mudança;
- aprovação formal para desligamento, promoção de capacidade e rollback;
- revisão de permissões temporárias após o evento.

## 10. Observabilidade e alertas

O painel da operação deve apresentar, no mínimo:

- disponibilidade e latência por canal e API crítica;
- taxa de erro por endpoint e código HTTP;
- conversão do checkout e abandono por etapa;
- pedidos criados, pagos, cancelados e pendentes;
- reservas de estoque e falhas de alocação;
- uso de CPU, memória, rede, disco e IOPS;
- quantidade de pods, reinícios, throttling e evictions;
- conexões e locks dos bancos de dados;
- throughput, erro e consumer lag do Kafka;
- filas de pagamento, antifraude, pedido e logística;
- status do Akamai, API Gateway, DNS, identidade e certificados.

Os alertas devem possuir owner, severidade, limiar, runbook e canal de escalonamento. Métricas de negócio devem ser correlacionadas com as métricas técnicas para distinguir falha de infraestrutura de queda de demanda ou falha de conversão.

## 11. Linha do tempo operacional

### T-90 a T-60 dias: planejamento

- nomear patrocinador, gerente do evento e owners técnicos;
- confirmar previsão de tráfego, pedidos, usuários simultâneos e volume logístico;
- inventariar recursos não produtivos elegíveis à desativação;
- definir metas de disponibilidade, latência, RTO e RPO;
- identificar dependências que não podem ser desligadas;
- reservar capacidade de cloud, licenças, suporte e fornecedores.

### T-45 a T-30 dias: preparação

- concluir testes de carga, stress, soak e failover;
- revisar limites do API Gateway, Akamai, Kubernetes, bancos e Kafka;
- testar o desligamento e a retomada de um ambiente não produtivo;
- validar backups e restauração;
- revisar dashboards, alertas, contatos e runbooks;
- congelar alterações estruturais no desenho da solução.

### T-14 a T-7 dias: ensaio geral

- executar simulação completa em janela controlada;
- medir o tempo real de desligamento e promoção de capacidade;
- confirmar que todos os serviços P0 têm capacidade e dependências disponíveis;
- revisar resultados com negócio, operações, segurança e fornecedores;
- corrigir gaps e obter aprovação go/no-go.

### T-1 dia: congelamento

- congelar deploys e mudanças não emergenciais;
- confirmar versões aprovadas, imagens e manifests;
- validar backups, replicação, certificados e acessos;
- comunicar a janela, a escala de plantão e o canal de incidentes;
- iniciar o desligamento gradual dos ambientes não produtivos.

### Durante o evento

- executar a expansão de produção por ondas;
- validar cada onda com smoke tests e métricas de saúde;
- acompanhar o painel de negócio e o painel técnico continuamente;
- registrar mudanças, incidentes, decisões e horários;
- aplicar degradação controlada quando os limiares forem atingidos;
- manter war room e escalonamento ativo durante toda a janela.

### T+1 a T+7 dias: retorno e revisão

- reduzir capacidade de produção gradualmente, após estabilização da demanda;
- religar ambientes não produtivos em ondas;
- reativar jobs, consumidores e pipelines na ordem documentada;
- executar reconciliação de pedidos, estoque, pagamentos e eventos;
- revisar custos, incidentes, alertas e capacidade utilizada;
- realizar post-mortem e atualizar o plano para o próximo evento.

## 12. Critérios de go/no-go

### Go

- testes de carga concluídos dentro dos objetivos definidos;
- backups e restauração validados;
- capacidade de produção aprovada por infraestrutura, dados e aplicação;
- Kafka e CDC sem lag ou falhas acima do limite acordado;
- owners e escala de plantão confirmados;
- rollback testado e com tempo conhecido;
- dependências externas e legadas confirmadas;
- dashboards e alertas operacionais funcionando.

### No-go

- ausência de rollback testado;
- falha de restauração ou replicação de dados;
- capacidade de banco, Kafka, rede ou legado sem headroom;
- erro ou latência acima do limite em teste de carga;
- dependência crítica sem owner ou contato de suporte;
- mudanças relevantes não reconciliadas com a infraestrutura como código;
- vulnerabilidade crítica aberta no caminho de produção;
- impossibilidade de observar pedidos, pagamentos, estoque ou eventos.

## 13. Degradação controlada

Quando a capacidade atingir os limites definidos, a operação deve seguir esta ordem:

1. servir conteúdo de catálogo e páginas elegíveis pelo Akamai;
2. reduzir ou pausar relatórios e rotinas analíticas;
3. limitar integrações de parceiros e chamadas de baixa prioridade;
4. colocar operações não críticas em filas duráveis;
5. aplicar fila virtual ou controle de entrada no checkout, se previsto;
6. preservar criação de pedido, pagamento, reserva e confirmação de segurança;
7. acionar o plano de incidente maior caso os indicadores P0 permaneçam degradados.

Não devem ser usados retries ilimitados. Retries precisam de backoff, limite e idempotência para evitar efeito cascata.

## 14. Rollback e contingência

O rollback será acionado pelo gerente do evento, com apoio do owner do serviço afetado, quando houver risco de perda de dados, indisponibilidade prolongada ou degradação sem tendência de recuperação.

Procedimento mínimo:

1. congelar novas alterações e registrar o estado atual;
2. proteger dados e offsets antes de qualquer reversão;
3. reduzir tráfego para o componente degradado;
4. retornar à última configuração aprovada;
5. restaurar réplicas, limites ou node pools conforme o runbook;
6. validar smoke tests, dados, filas e integrações;
7. comunicar o resultado e manter monitoramento reforçado.

O desligamento de não produtivos não deve ser revertido durante o pico apenas para recuperar capacidade de desenvolvimento. A prioridade é manter o serviço produtivo e preservar os recursos necessários para suporte e recuperação.

## 15. Matriz de responsabilidades

| Atividade | Arquitetura | Plataforma | Aplicação | Dados | Segurança | Negócio |
| --- | --- | --- | --- | --- | --- | --- |
| Aprovar metas e prioridades | R | C | C | C | C | A |
| Dimensionar capacidade | A | R | C | C | C | C |
| Desligar não produtivos | C | R | C | C | C | I |
| Validar dados e backups | C | C | C | R/A | C | I |
| Executar expansão produtiva | C | R | C | C | C | I |
| Monitorar operação | C | R | R | R | C | C |
| Decidir degradação | A | C | C | C | C | R |
| Acionar rollback | A | R | R | R | C | I |
| Executar pós-evento | R | R | R | R | R | A |

Legenda: **R** = responsável pela execução; **A** = responsável pela aprovação; **C** = consultado; **I** = informado.

## 16. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Desligamento interrompe uma dependência crítica | Alto | inventário de dependências, teste de desligamento e lista de exceções |
| Overselling por atraso de estoque | Alto | reserva idempotente, fonte de verdade definida e reconciliação |
| Sobrecarga de mainframe, IBM i ou DB2 | Alto | rate limit, cache, filas, limites de concorrência e escala de jobs |
| Consumer lag ou perda de eventos | Alto | replication factor, monitoramento de offsets, DLQ e reprocessamento testado |
| Falta de capacidade de banco | Alto | teste de carga, headroom, limites de conexão e plano de escala |
| Alteração emergencial não rastreada | Médio | change record obrigatório e reconciliação pós-evento |
| Retomada incompleta dos ambientes | Médio | runbook de startup por dependência e smoke tests |
| Dependência de fornecedor indisponível | Alto | contatos de plantão, SLA, fallback e testes prévios |
| Custos acima do esperado | Médio | orçamento aprovado, tags, alertas de custo e desligamento pós-evento |

## 17. Entregáveis obrigatórios

- inventário de recursos e dependências;
- baseline de capacidade e previsão de pico;
- arquitetura atualizada e diagrama de fluxos críticos;
- plano de desligamento e retomada de ambientes;
- plano de expansão de produção;
- plano de observabilidade e dashboards;
- runbooks de degradação, incidente e rollback;
- evidências de testes de carga, failover, backup e restauração;
- matriz de contatos e escalonamento;
- registro de decisões e aprovações;
- relatório pós-evento com métricas e ações corretivas.

## 18. Resultado esperado

Ao final da preparação, a organização deve conseguir desligar com segurança os recursos não produtivos elegíveis, direcionar a capacidade liberada para produção de forma mensurável e operar a Black Friday com proteção para pedidos, pagamentos, estoque, integrações e logística.

O sucesso do plano não é medido apenas pelo número de instâncias disponíveis. Ele é medido pela capacidade de atender o pico com dados consistentes, observabilidade ponta a ponta, degradação controlada e retorno previsível à operação normal.
