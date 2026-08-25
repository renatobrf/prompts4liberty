# Plano de Modernização e Expansão — Hybrid Cloud
## Gateway de Pagamentos

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Proposta para validação |
| Domínio | Meios de pagamento |
| Referências | `gateway-de-pagamentos.md` · `gateway-pagamentos-arquitetura-software.md` |
| Conformidade | BACEN / SPB / PIX / CNAB 240 / CNAB 400 / PCI-DSS / LGPD |
| Estratégia | Cargas síncronas e reguladas preservadas on-premises; cargas elásticas e analíticas na cloud |

> Este plano é uma proposta de arquitetura e capacidade. Os valores de custo são referências para controle e sizing; devem ser confirmados com métricas reais e com o AWS Pricing Calculator antes de contratação.

---

## 1. Objetivo

Modernizar o Gateway de Pagamentos para suportar crescimento de parceiros e picos de processamento sem perder rastreabilidade, disponibilidade, segurança ou controle financeiro. A abordagem utiliza **hybrid cloud**, mantendo no ambiente on-premises os componentes que exigem conectividade determinística com VAN/SPB, baixa latência ou maior controle regulatório, e transferindo para a cloud as cargas que se beneficiam de elasticidade, isolamento e pagamento por uso.

O plano cobre:

- expansão horizontal do Hiker e do Bulk Files Pipeline;
- absorção de picos de API, arquivos e liquidação;
- separação entre plano de controle e plano de dados;
- conectividade segura e resiliente entre on-premises e cloud;
- redução de custo por autoscaling, filas, classes de armazenamento e compromissos graduais;
- continuidade operacional, auditoria e conformidade para pagamentos.

## 2. Premissas e lacunas a validar

As metas atuais do projeto são: disponibilidade do gateway de pelo menos 99,9%, canal PIX 24x7x365, P95 de API abaixo de 500 ms, consultas NSU/E2E abaixo de 100 ms e processamento de pelo menos 100.000 registros por arquivo.

Antes do sizing definitivo, medir por no mínimo 30 dias:

| Métrica | Medição necessária |
|---|---|
| API | requisições por segundo, concorrência, P95/P99, payload médio e taxa de erro |
| Arquivos | arquivos/hora, registros/arquivo, bytes, layouts e janela de chegada |
| Hiker | tempo por registro, uso de CPU/memória e chamadas ao `configServerFiles` |
| Bulk files | registros/minuto, duração do lote, commits e contenção no PostgreSQL |
| Dados | crescimento diário, retenção, tamanho do event log e taxa de leitura do dashboard |
| Integrações | latência, limites e indisponibilidade de VAN, adquirentes e SPB |
| Custo | custo por transação, por arquivo e por milhão de registros |

Sem essa medição, os números deste documento devem ser tratados como **hipóteses de capacidade**, não como compromisso de infraestrutura.

## 3. Princípios de decisão

1. **Integridade financeira antes de throughput**: nenhuma otimização pode remover idempotência, reconciliação ou auditoria imutável.
2. **Processamento assíncrono por padrão para arquivos**: a chegada do arquivo não deve ficar bloqueada pelo tempo de validação ou carga.
3. **Escalonar consumidores, não bancos indiscriminadamente**: filas absorvem picos e protegem o PostgreSQL de tempestades de workers.
4. **Dados sensíveis minimizados**: PAN não entra na plataforma em claro; tokens, chaves e certificados ficam em HSM/KMS e Secret Manager.
5. **Capacidade base previsível, pico variável**: reservar somente o baseline comprovado e deixar o excesso sob demanda.
6. **Portabilidade seletiva**: workloads podem ser empacotados em containers, mas não se deve replicar complexidade on-premises e cloud sem uma necessidade operacional clara.
7. **Falha explícita e recuperável**: retries com backoff, dead-letter queue, replay controlado e circuit breaker.

## 4. Arquitetura-alvo hybrid cloud

### 4.1 Distribuição dos workloads

| Workload | Ambiente primário | Motivo | Expansão |
|---|---|---|---|
| VAN/SFTP/MQ e conectores SPB | On-premises | conectividade contratada, latência e controles existentes | cluster ativo-passivo ou ativo-ativo conforme parceiro |
| API de parceiros e webhooks | Cloud | elasticidade, WAF, rate limit e distribuição regional | horizontal por serviço |
| Hiker | Cloud, com runner on-premises de contingência | é stateless e demanda variável | ECS/Fargate ou Kubernetes por fila |
| `configServerFiles` | Cloud com réplica on-premises de leitura | configuração versionada e baixa latência de consulta | cache local + réplicas |
| Bulk Files Pipeline | Cloud | picos concentrados e processamento desacoplado | consumidores por profundidade da fila |
| Processamento regulado de saída | On-premises | janela e conectividade com VAN/SPB | workers controlados por limite do parceiro |
| PostgreSQL operacional | On-premises inicialmente, réplica cloud | controle, consistência e migração gradual | read replicas e particionamento; futura adoção de serviço gerenciado |
| Event log e auditoria | Cloud e cópia imutável on-premises | retenção, consulta e evidência | object storage com retenção WORM |
| Dashboard e analytics | Cloud | leitura elástica sem afetar transação | CDN, cache e data lake |

### 4.2 Diagrama lógico

```text
Parceiros / adquirentes
          |
     DNS + WAF + mTLS
          |
   Cloud: API Gateway / Kong
          |
   API Layer stateless ----------- Webhooks
          |                              |
          +---------- Event Bus ----------+
                         |
              SQS FIFO / filas por domínio
                 |                    |
        Hiker workers          Bulk workers
                 |                    |
       Object Storage         PostgreSQL writer
       (arquivo original)            |
                 |             Event log imutável
                 +-------------------+
                                     |
                    VPN/Direct Connect redundante
                                     |
 On-premises: VAN/SFTP/MQ -- SPB/BACEN -- PostgreSQL primário
          |                              |
  Outbound regulated workers       DR/read replica cloud
```

O vínculo entre ambientes deve ser tratado como uma integração distribuída, não como uma extensão transparente de rede. Cada mensagem precisa conter `arquivo_id` ou `transacao_id`, chave de idempotência, versão do contrato, timestamp e correlation ID.

## 5. Atualização técnica dos componentes

### 5.1 Entrada e API

- Usar API Gateway/Kong como plano de controle: mTLS por parceiro, JWT para operadores, rate limit por parceiro/rota e validação de schema OpenAPI.
- Separar rotas de baixa latência (`POST /transacoes`, PIX e estorno) de rotas de arquivo e consulta.
- Aplicar quotas independentes para `premium`, `standard`, `basic` e integrações internas; o limite de um parceiro nunca deve consumir toda a capacidade do domínio.
- Implementar idempotency key obrigatória em submissões financeiras e persistir a resposta original associada à chave.
- Colocar WAF, proteção contra abuso e allowlist de IP somente onde o contrato do parceiro exigir; não usar IP allowlist como único controle de identidade.

### 5.2 Hiker

O Hiker deve permanecer stateless por execução. O `HikerContext` completo não deve depender da memória do processo: o estado de checkpoint e a auditoria devem ser persistidos em storage durável.

Mudanças propostas:

- receber mensagens com referência ao objeto original no object storage, evitando replicar arquivos grandes em filas;
- particionar arquivos por blocos de registros quando o layout permitir, mantendo validação de header/trailer no coordenador;
- usar filas separadas por prioridade e parceiro;
- guardar checkpoints por `arquivo_id`, bloco e versão da regra;
- tornar cada passo reentrante e idempotente;
- emitir eventos `ArquivoClassificado`, `BlocoValidado`, `ArquivoAprovado`, `ArquivoRejeitado` e `CargaAutorizada`;
- aplicar limite de concorrência por parceiro para não violar contratos de VAN ou sobrecarregar o banco.

### 5.3 `configServerFiles`

- versionar regras como artefatos imutáveis, com aprovação de mudança e vigência explícita;
- distribuir uma réplica somente leitura e cache local com TTL curto;
- associar cada processamento à versão efetivamente usada;
- invalidar cache por evento de publicação, sem alterar arquivos já em processamento;
- bloquear publicação sem teste de regressão dos layouts CNAB, XML BACEN e JSON PIX.

### 5.4 Bulk Files Pipeline

- separar ingestão, validação, persistência e envio à adquirente em filas distintas;
- usar batches de escrita controlados, prepared statements e commits por bloco;
- aplicar backpressure quando o PostgreSQL atingir limite de CPU, I/O ou conexões;
- usar staging para registros aprovados antes da carga final em `fato_transacao`;
- manter deduplicação por hash SHA-256 do arquivo e chave de negócio por transação;
- enviar falhas não recuperáveis para DLQ com processo de revisão e replay auditado.

### 5.5 Dados e auditoria

- manter o PostgreSQL transacional separado do datastore do API Gateway;
- particionar `fato_transacao` e `transacao_evento` por período, conforme volume medido;
- usar pool de conexões, read replicas para consultas e réplica assíncrona para DR;
- exportar auditoria e arquivos originais para object storage com criptografia, versionamento e retenção WORM;
- não usar cache para substituir a fonte de verdade financeira;
- mascarar dados sensíveis em logs e proibir payload financeiro completo em traces.

## 6. Modelo de capacidade e picos

### 6.1 Cenários de referência

| Cenário | API | Arquivos | Estratégia |
|---|---:|---:|---|
| Baseline | 100 req/s | 2 arquivos/h | capacidade reservada, 2 réplicas mínimas |
| Pico diário | 500 req/s | 10 arquivos/h | autoscaling de API e consumidores |
| Pico sazonal | 1.000 req/s | 25 arquivos/h | pré-aquecimento, quotas e capacidade temporária |
| Recuperação | 200 req/s | backlog de 50 arquivos | prioridade, replay e janela controlada |

Esses valores são pontos de partida para teste de carga. O dimensionamento final deve usar:

```text
workers_necessarios = ceil(
  taxa_de_entrada * tempo_medio_de_processamento
  / (registros_por_worker * fator_de_utilizacao_alvo)
)
```

Usar fator de utilização alvo entre 0,60 e 0,70 para preservar margem de pico. Para uma fila, o indicador operacional mais importante é a idade da mensagem mais antiga, e não apenas CPU.

### 6.2 Políticas de autoscaling

| Componente | Escala por | Limite inicial sugerido |
|---|---|---|
| API Layer | CPU, concorrência, P95 e erros 5xx | min. 2, max. 20 tasks por serviço |
| Hiker | profundidade da fila e idade da mensagem | min. 2, max. 50 workers |
| Bulk writer | fila + conexões/CPU do PostgreSQL | max. definido pelo DB, não pela fila |
| Dashboard | requisições e conexões WebSocket | CDN/cache; escalonar origem separadamente |
| On-premises VAN | backlog e janela do parceiro | capacidade fixa com alerta de saturação |

Regras adicionais:

- scale-out rápido e scale-in lento para evitar flapping;
- cooldown maior no banco e menor nos consumidores stateless;
- fila de prioridade para PIX e transações em tempo real;
- limite absoluto de tasks para impedir que um erro de métrica gere custo descontrolado;
- teste de carga com tráfego sintético e dados não sensíveis antes de liberar o máximo.

### 6.3 SLOs operacionais

| Indicador | Meta | Ação ao violar |
|---|---|---|
| API transacional P95 | < 500 ms | reduzir carga, ativar réplicas e investigar dependência |
| Consulta NSU/E2E P95 | < 100 ms | read replica, índice ou particionamento |
| Idade da fila Hiker | < 5 min normal; < 15 min pico | expandir workers e aplicar prioridade |
| Arquivo de 100 mil registros | dentro da janela acordada | particionar e revisar throughput do writer |
| Taxa de erro financeiro | 0 erros silenciosos | parar replay automático e abrir incidente |
| Disponibilidade PIX | 24x7x365 | failover testado e operação on-call |

## 7. Resiliência hybrid cloud

### 7.1 Rede

- dois túneis VPN IPSec como mínimo; preferir Direct Connect redundante quando o volume e o SLA justificarem;
- roteamento e firewalls separados por ambiente e domínio;
- DNS com health checks apenas para endpoints idempotentes;
- mTLS também na comunicação serviço a serviço entre cloud e on-premises;
- nenhum banco exposto publicamente;
- testar perda de túnel, latência elevada e indisponibilidade de DNS.

### 7.2 Continuidade

| Serviço | RTO alvo | RPO alvo | Estratégia |
|---|---:|---:|---|
| API transacional | 30 min | próximo evento confirmado | cloud multi-AZ e failover operacional |
| Hiker/Bulk | 60 min | zero perda de arquivo confirmado | object storage + filas duráveis + checkpoint |
| PostgreSQL operacional | 60 min | até 5 min | réplica, backup PITR e runbook |
| Auditoria | 4 h | 0 | cópia imutável e versionada |
| VAN/SPB | conforme contrato | conforme protocolo | conectores redundantes on-premises |

O failover não deve duplicar uma transação. A recuperação precisa consultar o estado persistido e respeitar a mesma chave de idempotência usada no processamento primário.

## 8. Segurança, compliance e operação

- segmentar o CDE PCI-DSS, mantendo somente os componentes estritamente necessários dentro do escopo;
- usar HSM para chaves de tokenização e certificados de comunicação regulada;
- usar KMS para dados cloud e rotação automatizada de segredos;
- aplicar menor privilégio, MFA resistente a phishing e acesso administrativo just-in-time;
- registrar alterações de configuração, regras de layout, certificados, quotas e políticas de autoscaling;
- usar logs estruturados com `correlation_id`, `arquivo_id`, `transacao_id`, parceiro e versão de regra;
- criar controles de retenção LGPD por categoria de dado, sem apagar evidências regulatórias antes do prazo aplicável;
- executar testes de restauração, failover, replay de DLQ e rotação de certificados regularmente;
- manter segregação entre desenvolvimento, homologação e produção, incluindo contas/projetos cloud separados.

## 9. Controle de custos

### 9.1 Guardrails

| Controle | Implementação |
|---|---|
| Orçamento mensal | AWS Budgets por ambiente, domínio e centro de custo |
| Alertas | 50%, 80%, 100% e previsão de estouro |
| Tags obrigatórias | `produto`, `ambiente`, `servico`, `parceiro`, `centro_custo`, `criticidade` |
| Limite de autoscaling | máximo de tasks e workers por serviço |
| Observabilidade | retenção curta em logs quentes, amostragem de traces e métricas agregadas |
| Armazenamento | lifecycle de hot para cool/archive e expiração somente com aprovação de compliance |
| Rede | endpoints privados, compressão e redução de tráfego cross-region |
| Ambientes não produtivos | desligamento programado e escalas mínimas fora do horário |

### 9.2 Estratégia financeira

1. Operar os primeiros dois meses sob demanda e medir baseline, como já recomendado nos planos locais.
2. Comprar Compute Savings Plan somente para o consumo estável de API e workers.
3. Reservar PostgreSQL apenas após confirmar classe, Multi-AZ e estratégia de permanência do primário.
4. Manter capacidade de pico sob demanda; não reservar o pico sazonal.
5. Avaliar Spot somente para Hiker e cargas reprocessáveis, nunca para transação PIX, writer ou conectores regulados.
6. Comparar custo por transação processada, incluindo transferência, logs, filas e suporte, e não apenas custo de compute.

Uma fórmula simples de acompanhamento é:

```text
custo_unitario = custo_total_do_domínio / transações_confirmadas
```

O painel financeiro deve mostrar baseline, pico, custo unitário, forecast e percentual de recursos ociosos. Um aumento de custo pode ser aceitável se reduzir backlog e incidentes, mas deve ser explícito e aprovado.

## 10. Roadmap de implementação

### Fase 0 — Baseline e controles (0–30 dias)

- instrumentar métricas de API, Hiker, filas, PostgreSQL e custo;
- definir SLOs, RTO/RPO, ownership e runbooks;
- criar contas/projetos cloud separados e tagging obrigatório;
- validar contratos de conectividade com VAN, SPB e parceiros.

### Fase 1 — Desacoplamento seguro (31–90 dias)

- colocar object storage como repositório do arquivo original;
- introduzir filas duráveis, DLQ e idempotência;
- containerizar Hiker e Bulk Files sem mudar as regras de negócio;
- criar conectividade redundante cloud/on-premises;
- executar teste de carga baseline e pico diário.

### Fase 2 — Elasticidade controlada (91–180 dias)

- ativar autoscaling por fila, idade de mensagem e SLO;
- mover API e dashboard para cloud multi-AZ;
- manter processamento regulado de saída on-premises;
- habilitar réplica de leitura e backup PITR do PostgreSQL;
- aplicar budgets, limites de escala e lifecycle de storage.

### Fase 3 — Otimização e DR (181–270 dias)

- testar failover completo e replay sem duplicidade;
- revisar particionamento, retenção e custo unitário;
- avaliar migração do PostgreSQL primário para serviço gerenciado somente com evidência;
- comprar reservas para baseline comprovado;
- executar auditoria de PCI-DSS, LGPD e controles BACEN aplicáveis.

## 11. ADRs propostos

### ADR-01 — Filas como amortecedor de picos

**Decisão:** Hiker e Bulk Files serão acionados por filas duráveis, com escalonamento por backlog.

**Motivo:** desacopla chegada de arquivo da capacidade instantânea de processamento e protege o banco.

**Trade-off:** aumenta a latência de processamento e exige operação de DLQ/replay.

### ADR-02 — Execução regulada on-premises

**Decisão:** conectores VAN/SPB e a saída financeira regulada permanecem on-premises na primeira etapa.

**Motivo:** preserva conectividade, contratos e controles já estabelecidos.

**Trade-off:** mantém parte da infraestrutura fixa e exige operação de rede híbrida.

### ADR-03 — Elasticidade cloud para cargas reprocessáveis

**Decisão:** Hiker, ingestão, dashboard e analytics podem escalar na cloud; Spot só será usado em replay não crítico.

**Motivo:** maximiza elasticidade sem colocar transações financeiras em capacidade interrompível.

**Trade-off:** exige contratos de mensagem, checkpoint e observabilidade maduros.

### ADR-04 — PostgreSQL como fonte de verdade durante a transição

**Decisão:** não introduzir dois bancos transacionais ativos para a mesma transação.

**Motivo:** evita inconsistência e conciliação distribuída prematura.

**Trade-off:** o banco continua sendo um limite de throughput até particionamento ou migração futura.

## 12. Critérios de aceite

O plano estará pronto para produção quando:

- um arquivo duplicado não criar registros financeiros duplicados;
- perda de um worker, uma task ou um túnel não perder mensagens confirmadas;
- o backlog de pico voltar ao nível normal dentro da janela acordada;
- o PostgreSQL não ultrapassar limites definidos de CPU, I/O e conexões;
- custos de cloud emitirem alerta antes do orçamento ser excedido;
- logs e traces não expuserem PAN, credenciais ou payloads sensíveis;
- o failover e a restauração forem demonstrados com evidência;
- auditoria conseguir reconstruir o caminho do arquivo e da transação por `correlation_id`;
- qualquer regra de layout usada em produção puder ser identificada por versão.

## 13. Recomendação final

Adotar uma modernização híbrida incremental. A cloud deve absorver variabilidade e oferecer escala para API, Hiker, Bulk Files, dashboard e analytics; o on-premises deve continuar responsável pelos conectores VAN/SPB e pelo processamento de saída enquanto os requisitos de conectividade, auditoria e recuperação não forem comprovados na cloud.

A prioridade não é mover todos os componentes, mas criar uma fronteira operacional clara: **filas e object storage absorvem o pico, workers stateless escalam, o banco permanece protegido, e os compromissos financeiros cobrem somente o baseline medido**. Essa combinação reduz risco de migração, preserva controles de meios de pagamento e permite expansão gradual baseada em evidências.