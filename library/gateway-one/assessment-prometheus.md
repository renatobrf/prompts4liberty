# Avaliação de arquitetura — Prometheus no cluster do gateway de pagamentos

## 1. Objetivo da avaliação

Avaliar a adoção de Prometheus como base de monitoramento operacional para a solução de gateway de pagamentos executando nos próprios clusters que provêem a plataforma de processamento e integração. A avaliação considera um cenário em que o gateway já possui arquitetura distribuída, cargas de transação financeiras, requisitos de disponibilidade e necessidade de observabilidade local, sem depender de um produto de monitoramento externo como solução única.

A pergunta central é: Prometheus é uma escolha apropriada para esse ambiente, considerando os requisitos de performance, segurança, custos e operação do gateway?

## 2. Visão geral do contexto

A solução de gateway de pagamentos opera em um ambiente com:

- APIs de parceiros e webhooks;
- processamento de arquivos e eventos financeiros;
- filas distribuídas e workers de processamento;
- integrações com VAN, adquirentes, SPB, BACEN e canais regulados;
- necessidade de alta disponibilidade e rastreabilidade;
- picos de demanda e processamento concentrado por lote;
- exigência de observabilidade em tempo real para transações, filas e integrações.

Nesse tipo de ambiente, a observabilidade precisa cobrir não apenas infraestrutura, mas também comportamento funcional do gateway: latência de endpoints, fila de processamento, saturação do banco, retries, falhas de integração, erro de validação e tempo de processamento por bloco ou transação.

## 3. Requisitos do monitoramento

### 3.1 Requisitos funcionais

- coletar métricas de infraestrutura e aplicação;
- acompanhar taxa de erro, latência e throughput de APIs;
- medir filas, workers, tempo de processamento e backlog;
- monitorar bancos de dados principais e réplicas;
- verificar integridade do fluxo de arquivos e processamento do Hiker;
- detectar degradação, falhas e saturação antes da interrupção do serviço;
- suportar alertas por limiar, janela e condições de negócio;
- permitir consulta histórica em curto e médio prazo.

### 3.2 Requisitos não funcionais

- baixa latência na coleta e agregação;
- escalabilidade em ambiente distribuído;
- suporte a múltiplos serviços e namespaces;
- rastreabilidade de eventos e alertas;
- segurança e controle de acesso;
- operação simples dentro do próprio cluster;
- custo controlado em capacidade computacional e armazenamento.

## 4. Por que considerar Prometheus

Prometheus é uma solução muito apropriada para monitoramento de infraestrutura e serviços em ambientes Kubernetes e clusters modernos. Ele se destaca em cenários em que a necessidade é:

- coleta de métricas em formato de séries temporais;
- alertas baseados em expressões e limiares;
- observabilidade de aplicações em runtime;
- monitoramento de throughput, latência e falhas por serviço;
- integração natural com Kubernetes, exporters, ServiceMonitor e alert rules.

No contexto do gateway, o Prometheus agrega valor em pelo menos três áreas principais:

1. observabilidade operacional da plataforma;
2. monitoramento dos serviços do gateway por endpoint, fila e worker;
3. suporte a alertas precoces de picos, degradação e falhas de integração.

## 5. Arquitetura alvo proposta

### 5.1 Modelo de implantação

A recomendação é implantar Prometheus dentro do próprio cluster que hospeda a solução do gateway, com uma arquitetura simples e operacionalmente previsível:

- Prometheus principal em modo HA ou cluster de monitoramento leve;
- exporters para os serviços relevantes;
- scraping por endpoint HTTP exposto por cada componente;
- Alertmanager para roteamento de alertas;
- Grafana para visualização e dashboards operacionais;
- integração com regras de negócio e alertas por domínio.

### 5.2 Componentes

| Componente | Função |
|---|---|
| Prometheus | coleta e armazenamento de métricas em séries temporais |
| Node Exporter | métricas de host e sistema |
| Kube-State-Metrics | métricas de objetos Kubernetes |
| blackbox-exporter | checagem externa de endpoints e integrações |
| PostgreSQL Exporter | dados do banco transacional |
| Redis Exporter | fila e cache |
| application exporters | métricas customizadas do gateway e Hiker |
| Alertmanager | roteamento e agrupamento de alertas |
| Grafana | dashboards e consultas operacionais |

### 5.3 Distribuição funcional

- Prometheus para coleta de métricas do cluster e do gateway;
- exporters para serviços e integrações críticas;
- alertas operacionais para disponibilidade e degradação;
- dashboards por domínios: API, Hiker, Bulk Files, banco, WAN/partner, fila e PIX.

## 6. Requisitos de monitoramento do gateway

A solução deve acompanhar, pelo menos, os seguintes aspectos:

### 6.1 API e parceiros

- latency P95/P99 por rota;
- throughput por parceiro;
- taxa de erro 4xx/5xx por endpoint;
- rejeições por schema, idempotência e validação;
- uso de WAF e rate limit;
- tempo de resposta de integrações externas.

### 6.2 Processamento de arquivos

- número de arquivos recebidos por minuto;
- registros por arquivo e por lote;
- tempo de ingestão, validação e persistência;
- backlog das filas;
- taxa de rejeição por layout, chave duplicada ou regra de negócio;
- duração do processamento do Hiker e Bulk Files.

### 6.3 Banco de dados

- CPU, I/O, memória do PostgreSQL;
- conexões ativas e esperadas;
- tempo de transação e queries lentas;
- deadlocks, locks e contorno de filas;
- throughput de commits e volume de gravação.

### 6.4 Integridade operacional

- erros de ingestão e retry;
- falhas de parceiros e VAN/SPB;
- tempo de processamento de uma transação completa;
- taxa de eventos em DLQ;
- disponibilidade dos túnel de rede e conectores externos.

## 7. Arquitetura de coleta

### 7.1 Risco e estratégia

Prometheus funcione bem quando a coleta é orientada a métricas, e o ambiente possui volume moderado de séries. No gateway de pagamentos, o desafio não é a coleta em si, mas a quantidade de dimensões possíveis: partner, rota, tipo de transação, status, operação, ambiente, região, worker, arquivo e idempotência.

Se a arquitetura não for controlada, o número de séries pode crescer rapidamente e tornar o sistema pesado. Portanto, a solução deve seguir disciplina de cardinalidade.

### 7.2 Regras de cardinalidade

A cardinalidade deve ser controlada com cuidado. Evitar etiquetas excessivas em métricas de alta frequência, como:

- `partner_id` em todas as métricas duras quando houver muitos parceiros;
- `transacao_id` como label;
- `arquivo_id` em histórico de alta frequência;
- `request_id` em séries de latência por endpoint;
- identificadores únicos muito granulares por evento.

Métricas críticas devem usar apenas labels de negócio estáveis, como:

- parceiro agrupado por categoria;
- rota ou endpoint;
- status operacional;
- região;
- ambiente;
- tipo de processamento.

## 8. Modelo de métricas do gateway

### 8.1 Propostas de métricas de negócio e infraestrutura

- `gateway_http_requests_total{route,method,status,partner}`
- `gateway_http_request_duration_seconds_bucket{route,method}`
- `gateway_queue_depth{queue_name}`
- `gateway_queue_age_seconds{queue_name}`
- `gateway_hiker_jobs_total{status}`
- `gateway_hiker_duration_seconds{stage}`
- `gateway_bulk_records_processed_total{tenant}`
- `gateway_db_connections{state}`
- `gateway_postgres_query_duration_seconds_bucket{query}`
- `gateway_partner_errors_total{partner,status}`
- `gateway_retries_total{operation,reason}`
- `gateway_file_processing_duration_seconds{file_type}`

Essas métricas servem para observar desempenho e falhas sem expor dados sensíveis ou identificadores pessoais.

## 9. Alertas recomendados

### 9.1 Alertas de infraestrutura

- CPU, memória e disco acima do limite em nós do cluster;
- saturação de memória em workers do gateway;
- crescimento excessivo do backlog de filas;
- aumento de latência em promédio e p95;
- redes com queda de conectividade ou erro de túnel.

### 9.2 Alertas de aplicação

- taxa de erro em endpoints financeiros acima do limite;
- fila de processamento acumulando mensagens;
- baixa taxa de processamento de arquivos;
- rejeição elevada por layout ou regra de negócio;
- picos de timeout em partner integrations;
- queda de ingestão de arquivos ou transações.

### 9.3 Alertas de negócio

- crescimento atípico de rejeições de pagamento;
- erro em canal PIX ou SPB;
- backlog de liquidação além da janela aceitável;
- latência de retorno de status de pagamento acima do SLO;
- falha de idempotência ou repetição de transação.

## 10. Alertmanager e roteamento

O Alertmanager deve ser usado para centralizar e rotear alertas. A política recomendada é:

- alertas críticos para canal de resposta imediata;
- alertas de warning para time de operação;
- alerts de negócio para chamadores do domínio do produto;
- grupos por componente, serviço e nível de severidade;
- silencing e inhibition controlados para evitar alert storm.

Exemplos de regras de roteamento:

- API financeira crítica -> PagerDuty / Slack / e-mail de resposta imediata;
- filas de processamento -> canal de operação do gateway;
- integrações externas -> time de integração e operação de rede;
- regras de negócio -> time de produto e gateway.

## 11. Dashboards essenciais

### 11.1 Dashboard de disponibilidade

- disponibilidade por API e parceiro;
- taxa de erro por rota;
- latency P95/P99;
- filas por estado;
- nível de processamento por worker.

### 11.2 Dashboard de processamento

- throughput de transações por minuto;
- registros por arquivo e por lote;
- tempos por etapa do fluxo;
- backlog e idade da fila;
- error rate por tipo de processamento.

### 11.3 Dashboard de infraestrutura

- CPU, memória, disco e rede por nó;
- uso do PostgreSQL;
- saturation por pod/worker;
- consumo de recursos por namespace;
- capacidade do cluster em picos.

## 12. Integração com o cluster do gateway

A integração com o cluster deve seguir um padrão simples e previsível:

- cada serviço do gateway deve expor um endpoint de métricas;
- o exporter ou sidecar deve ser colocado em cada pod crítico;
- a coleta deve usar scraping estável e intervalos moderados;
- o Prometheus deve ler somente métricas relevantes no nível de runtime;
- o cluster deve ter regras de segurança para impedir exposição indiscriminada de endpoints de métricas.

## 13. Trade-offs da solução

### 13.1 Pontos fortes

- alta maturidade e ampla adoção em ambientes Kubernetes;
- excelente integração com observabilidade de infraestrutura e serviços;
- baixo custo operacional comparado a plataformas de monitoramento mais pesadas;
- boas opções de alertas e dashboards;
- arquitetura simples de coleta baseada em scraping;
- adequado para ambientes de produção com vários componentes e cargas variáveis.

### 13.2 Pontos fracos

- menor conveniência para dados de alta cardinalidade;
- exige disciplina de regras de scrape e labels;
- não é solução completa para tracing distribuído;
- demanda bons padrões de instrumentação da aplicação;
- pode exigir esforço adicional para separar métricas financeiras de métricas operacionais;
- armazenamento histórico limitado se não houver boas políticas de retenção e gerenciamento de volume.

### 13.3 Riscos principais

- cardinalidade excessiva gerando consumo desnecessário de memória e CPU;
- ausência de instrumentação padronizada em serviços do gateway;
- alertas gerando ruido operacional se regras forem mal calibradas;
- vigilância focada em infraestrutura e não em comportamento do processo financeiro;
- promQL e dashboards mal modelados, dificultando análise de incidentes reais.

## 14. Recomendação de desenho operacional

A solução recomendada é implantar uma base de monitoramento Prometheus no próprio cluster do gateway com desenho explícito de maturidade operacional.

### 14.1 Estrutura recomendada

- 1 ou 2 instâncias Prometheus primárias em HA leve;
- Alertmanager dedicado;
- Grafana para visualização;
- exporters para Kubernetes, PostgreSQL, Redis, APIs e workers;
- instrumentação customizada do gateway por domínio funcional;
- regras de alerta por domínio e severidade.

### 14.2 Política de coleta

- intervalos de scrape curtos para APIs e filas críticas;
- intervalos mais longos para métricas de infra menos sensíveis;
- coleta por serviço e namespace;
- etiquetas estabilizadas e sem dados pessoais ou identificadores financeiros sensíveis;
- retenção de curto e médio prazo clara.

## 15. Críticas e limites da proposta

Prometheus é excelente para monitoramento de estado e performance operacional, mas não substitui algumas funções de observabilidade mais profundas:

- tracing distribuído;
- correlação de logs por request;
- análise de regressão semântica do negócio;
- observabilidade de dados sensíveis em fluxo de alta cardinalidade.

Portanto, a recomendação é tratá-lo como base da observabilidade do gateway, e não como solução completa de observabilidade do negócio. Quando necessário, deve haver complementaridade com logs estruturados, tracing e dashboards de processo financeiro.

## 16. Critérios de aceitação

O uso de Prometheus será considerado adequado quando:

- cada serviço do gateway expuser métricas relevantes;
- a latência, throughput e taxa de erro da API estiverem visíveis por rota e parceiro;
- o backlog de fila, tempo de processamento e erro de worker estiverem controlados;
- as regras de alerta forem acionadas antes da degradação crítica;
- o cluster do gateway não sofrer queda de performance significativa pela coleta;
- os dashboards permitirem decisões operacionais rápidas sem consulta intensa a logs;
- a cardinalidade for controlada e o volume de dados permanecer sustentável.

## 17. Recomendação final

A adoção de Prometheus no próprio cluster do gateway é uma escolha arquitetural defensável quando a solução precisa de observabilidade operacional local, baixa complexidade de integração e forte apoio para alertas e dashboards. Para um ambiente financeiro com APIs, filas, arquivos e integrações externas, Prometheus é uma base sólida de monitoramento, desde que a instrumentação seja disciplinada e a cardinalidade seja controlada.

A solução deve ser implementada como parte da plataforma operacional do gateway, integrada a métricas de negócio, filas e conectores externos, e apoiada por Alertmanager e Grafana. Isso permite operar com maior previsibilidade, reduzir tempo de resposta a incidentes e apoiar o crescimento do processamento sem depender de uma camada de monitoramento externa e dispendiosa.

## 18. Conclusão

Prometheus no próprio cluster é uma opção arquitetural adequada para monitorar a solução de gateway, desde que seja tratada como uma base de observabilidade operacional, não como um substituto para todo o conjunto de monitoramento do negócio. Com a correta instrumentação, alertas calibrados e controle de cardinalidade, ela oferece boa relação custo-benefício, elevada maturidade e forte aderência ao ambiente de Kubernetes e processamento distribuído.
