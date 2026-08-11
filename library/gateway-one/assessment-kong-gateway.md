# Avaliação de Arquitetura — Kong Gateway
## Aplicação ao Projeto: Gateway de Pagamentos — Plataforma de Processamento Financeiro

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Rascunho |
| Documento Base | `gateway-pagamentos-arquitetura-software.md` v1.0 |
| Solução Avaliada | Kong Gateway (Community / Enterprise) |
| Domínio | Meios de Pagamento — Infraestrutura de API |
| Conformidade Relevante | BACEN / SPB / PIX / PCI-DSS / LGPD / Resolução BACEN 4.658 |

---

## Índice

1. [Propósito e Escopo da Avaliação](#1-propósito-e-escopo-da-avaliação)
2. [Visão Geral do Kong Gateway](#2-visão-geral-do-kong-gateway)
3. [Mapeamento Arquitetural](#3-mapeamento-arquitetural)
4. [Avaliação por Camada Arquitetural](#4-avaliação-por-camada-arquitetural)
5. [Avaliação por Atributo de Qualidade](#5-avaliação-por-atributo-de-qualidade)
6. [Avaliação de Segurança e Compliance](#6-avaliação-de-segurança-e-compliance)
7. [Avaliação de Plugins Relevantes](#7-avaliação-de-plugins-relevantes)
8. [Lacunas e Riscos Identificados](#8-lacunas-e-riscos-identificados)
9. [Recomendações Arquiteturais](#9-recomendações-arquiteturais)
10. [ADRs Propostos](#10-adrs-propostos)
11. [Pontuação de Adequação](#11-pontuação-de-adequação)
12. [Glossário Complementar](#12-glossário-complementar)

---

## 1. Propósito e Escopo da Avaliação

Este documento avalia a adequação do **Kong Gateway** como componente de infraestrutura de API para o projeto **Gateway de Pagamentos**, considerando os requisitos descritos no documento de arquitetura de referência.

### 1.1 Objetivos da Avaliação

| # | Objetivo |
|---|---|
| AV1 | Verificar se o Kong atende aos requisitos de segurança PCI-DSS e BACEN |
| AV2 | Avaliar a capacidade do Kong de suportar os fluxos de negócio descritos (PIX, Batch, Estorno, Liquidação) |
| AV3 | Identificar quais plugins Kong cobrem os requisitos da API Layer atual |
| AV4 | Apontar lacunas onde o Kong não substitui ou não complementa componentes existentes |
| AV5 | Propor uma arquitetura de integração Kong + componentes internos |

### 1.2 Escopo

**Dentro do escopo:**
- API Layer (6.4) e seus endpoints
- Segurança e controle de acesso (seção 10)
- Integrações externas via API REST (seção 9)
- Atributos de qualidade: disponibilidade, desempenho, observabilidade (seção 11)

**Fora do escopo desta avaliação:**
- Componente Hiker (validação interna de arquivos)
- Bulk Files Pipeline (processamento batch)
- VAN / SFTP (protocolo não-HTTP)
- Modelo de dados interno (star schema / PostgreSQL)

---

## 2. Visão Geral do Kong Gateway

O **Kong Gateway** é uma plataforma de API Gateway de alto desempenho construída sobre **NGINX + OpenResty (LuaJIT)**. Atua como proxy reverso inteligente, oferecendo:

```
┌─────────────────────────────────────────────────────────────┐
│                      KONG GATEWAY                           │
│                                                             │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Rate     │  │   Auth   │  │  Logging │  │ Transform│  │
│  │ Limiting  │  │ (mTLS /  │  │ & Tracing│  │ Request/ │  │
│  │           │  │  API Key)│  │          │  │ Response │  │
│  └───────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                        Kong Core (Proxy)                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Admin API  │  Kong Manager  │  Kong Dev Portal     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
              │                            │
     Clientes / Parceiros           Serviços Upstream
     (API REST)                     (API Layer interna)
```

### 2.1 Edições Disponíveis

| Edição | Características Relevantes para o Projeto |
|---|---|
| **Kong Community (OSS)** | Proxy, plugins básicos (rate limit, auth, logging). Sem Kong Manager UI, sem RBAC avançado |
| **Kong Enterprise** | RBAC completo, Kong Manager, Dev Portal, plugins avançados (OpenID Connect, Vault, OPA), suporte oficial |
| **Kong Konnect (SaaS)** | Plano de controle gerenciado, dataplane auto-hospedado. Exige avaliação de residência de dados (LGPD) |

> **Recomendação preliminar**: Para o contexto PCI-DSS e BACEN 4.658, a edição **Enterprise auto-hospedada** é fortemente recomendada para controle total do ambiente e auditoria.

---

## 3. Mapeamento Arquitetural

### 3.1 Posicionamento do Kong na Arquitetura Atual

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GATEWAY DE PAGAMENTOS (revisado)                │
│                                                                         │
│   ┌──────────┐    ┌─────────────────────────────────────────────────┐  │
│   │ Parceiros│    │                 Kong Gateway                    │  │
│   │          │    │  (novo: ponto único de entrada API)             │  │
│   │ Bancos   │◄───│  mTLS · API Key · Rate Limit · Logging · Tracing│  │
│   │ Fintechs │    │  Request Validation · Transformation           │  │
│   │ Varejistas    └──────────────────────┬──────────────────────────┘  │
│   └──────────┘                           │                             │
│                              ┌───────────▼─────────────┐              │
│                              │       API Layer          │              │
│                              │  (serviços internos)     │              │
│                              └───────────┬─────────────┘              │
│                                          │                             │
│   VAN/SFTP ──► Hiker ──► Bulk Files ──► Data Store (PostgreSQL)        │
│                                          │                             │
│                              ┌───────────▼─────────────┐              │
│                              │  Dashboard Operacional   │              │
│                              └─────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────────┘
              │                                     │
              ▼                                     ▼
     Redes Adquirentes                      SPB / BACEN / PIX
```

### 3.2 Serviços Kong Mapeados aos Endpoints da API Layer

| Rota Kong | Upstream (API Layer) | Método | Descrição |
|---|---|---|---|
| `/v1/transacoes` | `svc-transacoes` | POST | Submissão de nova transação |
| `/v1/transacoes/{nsu}` | `svc-transacoes` | GET | Consulta por NSU |
| `/v1/transacoes/{e2e}/pix` | `svc-pix` | GET | Consulta PIX por E2E ID |
| `/v1/transacoes/{id}/estorno` | `svc-estorno` | POST | Solicitação de estorno |
| `/v1/arquivos/{id}/status` | `svc-hiker` | GET | Status Hiker por arquivo |
| `/v1/webhooks/adquirente` | `svc-webhook` | POST | Retorno rede adquirente |

---

## 4. Avaliação por Camada Arquitetural

### 4.1 Camada de Entrada

| Requisito Atual | Suporte Kong | Avaliação |
|---|---|---|
| API REST com parceiros autenticados | ✅ nativo | Kong como único ponto de entrada, concentrando autenticação |
| mTLS por parceiro comercial | ✅ plugin `mtls-auth` | Certificados gerenciados pelo Kong; mapeamento por `consumer` |
| API Key por parceiro | ✅ plugin `key-auth` | Complementar ao mTLS ou como fallback |
| Segregação por parceiro (multi-tenant) | ✅ via `consumers` + `routes` | Cada parceiro = consumer Kong com plugins escopados |
| Recebimento de webhooks adquirentes | ✅ via route dedicada | Recomenda autenticação separada (HMAC / IP allowlist) |

### 4.2 Camada de Processamento

| Componente | Papel Kong | Observação |
|---|---|---|
| **Hiker** | ❌ sem interação direta | Processamento interno de arquivo — Kong não atua aqui |
| **configServerFiles** | ⚠️ parcialmente | Kong não valida regras CNAB; apenas roteamento de config REST |
| **Bulk Files Pipeline** | ❌ fora de escopo Kong | Processamento batch assíncrono — não é responsabilidade do gateway |
| **API Layer** | ✅ upstream Kong | Kong roteia, autentica e filtra todas as chamadas à API Layer |

### 4.3 Camada de Dados

Kong não acessa diretamente o modelo de dados (PostgreSQL / star schema). A interação é indireta: Kong → API Layer → PostgreSQL.

> O Kong possui seu **próprio datastore** (PostgreSQL ou Cassandra para Enterprise) para configurações e plugins. Este banco deve ser **isolado** do banco de pagamentos — nunca compartilhado.

---

## 5. Avaliação por Atributo de Qualidade

### 5.1 Disponibilidade

| Meta Projeto | Capacidade Kong | Avaliação |
|---|---|---|
| Gateway ≥ 99,9% | Kong cluster ativo-ativo suporta 99,99% | ✅ **Supera** o requisito com deployment multi-nó |
| PIX 24×7×365 | Kong sem janela de manutenção (rolling restart) | ✅ **Atende** — deploys sem downtime via `kong reload` |
| API REST ≥ 99,5% | Monitoramento de health check upstream integrado | ✅ **Atende** — circuit breaker via plugin passivo |

**Topologia recomendada para alta disponibilidade:**

```
Load Balancer (externo)
        │
   ┌────┴────┐
   │         │
Kong Node 1  Kong Node 2   ←── cluster ativo-ativo
   │         │
   └────┬────┘
        │
   API Layer (upstream)
```

### 5.2 Desempenho

| Meta Projeto | Capacidade Kong | Avaliação |
|---|---|---|
| Latência API P95 < 500ms | Overhead Kong tipicamente < 2ms (LuaJIT) | ✅ **Supera** — overhead insignificante |
| Throughput ≥ 100k registros/arquivo | Irrelevante para Kong (batch via VAN) | ➖ **Não aplicável** ao Kong |
| Consulta NSU/E2E < 100ms | Kong não impacta; latência é do DB upstream | ✅ **Neutro** — Kong adiciona < 2ms |

**Considerações de desempenho:**
- O plugin `rate-limiting` com armazenamento em Redis adiciona ~1ms por requisição
- Plugins com chamadas externas (ex: OPA para autorização) podem adicionar 5–20ms — planejar SLO interno
- Habilitar `proxy-cache` para respostas de consulta (`GET /transacoes/{nsu}`) pode reduzir carga do upstream

### 5.3 Escalabilidade

Kong é **horizontalmente escalável** por natureza:

- Novos nós Kong adicionados sem reconfiguração de rotas (configuração compartilhada via DB)
- `consumers` (parceiros) adicionados via Admin API sem impacto em nós existentes
- Plugins com estado (rate limiting) exigem Redis compartilhado entre nós do cluster

### 5.4 Observabilidade

| Requisito Projeto | Plugin Kong | Capacidade |
|---|---|---|
| Eventos de auditoria por passo Hiker | ❌ Hiker é interno | Kong não emite eventos do Hiker |
| Log de acesso por parceiro | ✅ `http-log` / `file-log` / `tcp-log` | Logs estruturados com `consumer.id`, `route`, latência |
| Rastreamento distribuído | ✅ `zipkin` / `opentelemetry` | Trace ID propagado para o upstream (correlação com logs internos) |
| Métricas de API | ✅ `prometheus` | Exporta métricas para Prometheus/Grafana |
| Alertas de falha | ⚠️ via Prometheus + Alertmanager | Kong não alerta nativamente; requer stack de observabilidade |

---

## 6. Avaliação de Segurança e Compliance

### 6.1 PCI-DSS

| Requisito PCI-DSS | Cobertura Kong | Observação |
|---|---|---|
| Nunca armazenar PAN em claro | ⚠️ **Atenção crítica** | Kong loga o body das requisições se mal configurado — **desabilitar body logging** em rotas de cartão |
| TLS 1.2+ em trânsito | ✅ nativo | Kong termina TLS com certificados gerenciados; configurar `ssl_protocols TLSv1.2 TLSv1.3` |
| Criptografia de dados em repouso | ⚠️ parcial | Banco de dados do Kong (config) deve ter encryption at rest habilitada |
| Segmentação de rede | ✅ via rotas e plugins | Kong pode funcionar como segmento de rede de entrada, isolando a API Layer |
| Auditoria de acessos | ✅ via logging plugins | Logs de acesso por `consumer` com timestamp, rota, status HTTP |
| Escopo PCI restrito | ✅ contribui para redução | Kong centraliza ponto de entrada, reduzindo escopo de auditoria |

> ⚠️ **Risco PCI crítico**: O plugin `request-transformer` e logs de requisição HTTP **jamais devem capturar o campo `token_cartao`** ou qualquer campo de payload sensível. Aplicar `request-transformer` para mascarar/remover campos antes do logging é obrigatório.

### 6.2 Conformidade BACEN (Resolução 4.658)

| Requisito BACEN 4.658 | Suporte Kong | Observação |
|---|---|---|
| Controle de acesso com autenticação forte | ✅ mTLS + MFA no Admin | Parceiros via mTLS; Admin API protegida por RBAC Enterprise |
| Rastreabilidade de operações | ✅ `correlation-id` + logging | Propagar `X-Correlation-ID` para rastreamento E2E |
| Resposta a incidentes (logs forenses) | ✅ logs imutáveis externos | Logs exportados para SIEM externo (ELK, Splunk) com retenção configurável |
| Inventário de ativos críticos | ✅ Kong Admin API | Catálogo de rotas, consumers e plugins como inventário versionável |
| Gestão de vulnerabilidades | ⚠️ responsabilidade operacional | Kong deve ser atualizado regularmente; monitorar CVEs da imagem Docker |

### 6.3 PIX — Exigências BACEN

| Exigência PIX | Solução Kong |
|---|---|
| Disponibilidade 24×7×365 | Cluster ativo-ativo + rolling restart |
| Identificação E2E (`end_to_end_id`) | Plugin `correlation-id` injetando/preservando o E2E ID nos headers |
| Latência de resposta | Kong adiciona < 2ms; SLO total preservado |
| Autenticação da chamada | mTLS obrigatório na rota `/v1/transacoes/{e2e}/pix` |

### 6.4 LGPD

| Requisito LGPD | Avaliação Kong |
|---|---|
| Minimização de dados em logs | ⚠️ **Requer configuração** — mascarar CPF, dados do titular nos logs Kong |
| Anonimização | Plugin `request-transformer` pode remover/mascarar campos antes do logging |
| Retenção de dados | Logs exportados; política de retenção no destino (SIEM/S3) — fora do Kong |
| Residência de dados | Konnect SaaS: **contraindicado**; Kong on-premises: ✅ dados residem no Brasil |

---

## 7. Avaliação de Plugins Relevantes

### 7.1 Autenticação e Autorização

| Plugin | Caso de Uso no Projeto | Edição | Prioridade |
|---|---|---|---|
| `mtls-auth` | Autenticação de parceiros comerciais (já previsto na arquitetura) | OSS + Enterprise | 🔴 Alta |
| `key-auth` | API Key como segunda camada ou fallback de autenticação | OSS | 🟡 Média |
| `openid-connect` | SSO para Dashboard Operacional (Admin) | Enterprise | 🟡 Média |
| `oauth2` | Autenticação OAuth2 para parceiros que não usam mTLS | OSS | 🟡 Média |
| `acl` | Segregação de acesso por grupo (parceiro A não acessa rotas do parceiro B) | OSS | 🔴 Alta |

### 7.2 Segurança e Proteção

| Plugin | Caso de Uso no Projeto | Edição | Prioridade |
|---|---|---|---|
| `rate-limiting` | Throttling por parceiro (evitar sobrecarga no pipeline) | OSS (Redis para cluster) | 🔴 Alta |
| `rate-limiting-advanced` | Rate limiting sliding window, por consumer/rota/IP | Enterprise | 🟡 Média |
| `bot-detection` | Proteção da rota de webhooks adquirentes | Enterprise | 🟡 Média |
| `ip-restriction` | Allowlist de IPs para rotas de webhook de adquirentes | OSS | 🔴 Alta |
| `request-validator` | Validação de schema JSON no entry point (ex: PIX payload) | Enterprise | 🔴 Alta |
| `vault` (Kong Vault) | Gerenciamento de secrets (API Keys, certificados) via Vault externo | Enterprise | 🟠 Alta (compliance) |

### 7.3 Observabilidade e Rastreamento

| Plugin | Caso de Uso no Projeto | Edição | Prioridade |
|---|---|---|---|
| `correlation-id` | Injetar/propagar `X-Correlation-ID` para rastreamento E2E (incl. PIX E2E ID) | OSS | 🔴 Alta |
| `prometheus` | Métricas de latência, throughput, erros por rota/consumer | OSS | 🔴 Alta |
| `opentelemetry` | Trace distribuído integrando Kong → API Layer → DB (OTEL collector) | OSS | 🟡 Média |
| `zipkin` | Alternativa ao OTEL para trace distribuído | OSS | 🟡 Média |
| `http-log` | Exportar logs estruturados para SIEM (ELK, Splunk) | OSS | 🔴 Alta |
| `file-log` | Log local para diagnóstico (não usar em produção como destino principal) | OSS | 🟢 Baixa |

### 7.4 Transformação e Roteamento

| Plugin | Caso de Uso no Projeto | Edição | Prioridade |
|---|---|---|---|
| `request-transformer` | Mascarar campos sensíveis (CPF, token_cartao) antes do logging; adicionar headers de auditoria | OSS | 🔴 Alta |
| `response-transformer` | Padronizar envelopes de resposta da API Layer | OSS | 🟡 Média |
| `proxy-cache` | Cache de respostas GET (consulta NSU/E2E) para reduzir carga no DB | Enterprise | 🟡 Média |
| `grpc-gateway` | Transcodificação gRPC↔REST (caso upstream evolua para gRPC) | OSS | 🟢 Baixa |

---

## 8. Lacunas e Riscos Identificados

### 8.1 Lacunas de Cobertura

| ID | Lacuna | Impacto | Mitigação |
|---|---|---|---|
| L01 | Kong não processa arquivos CNAB/binários (VAN/SFTP) | Alto — fluxo batch principal fora do Kong | Manter VAN/SFTP direto; Kong atua apenas na camada REST |
| L02 | Kong não executa lógica de negócio do Hiker | Alto — validação de layout é específica do domínio | Hiker permanece componente interno; Kong apenas roteia |
| L03 | Kong não valida conformidade CNAB 240/400 | Médio — validação de payload financeiro complexo | `request-validator` cobre JSON simples; CNAB requer Hiker |
| L04 | Banco de dados Kong separado do banco de pagamentos | Médio — duas bases a gerenciar | Planejar backup, HA e monitoramento do DB Kong separadamente |
| L05 | Kong Konnect (SaaS) incompatível com residência de dados LGPD | Alto se usar Konnect | Usar Kong on-premises ou Konnect com dataplane self-hosted |

### 8.2 Riscos Arquiteturais

| ID | Risco | Probabilidade | Severidade | Ação |
|---|---|---|---|---|
| R01 | Vazamento de PAN via logs Kong mal configurados | Baixa | **Crítica** (PCI) | Obrigatório: desabilitar body logging; usar `request-transformer` para mascarar |
| R02 | Single Point of Failure se Kong não for clusterizado | Média | Alta | Deploy em cluster ativo-ativo com load balancer externo |
| R03 | Overhead de latência com plugins em cadeia | Média | Média | Benchmark antes de produção; limitar plugins por rota ao necessário |
| R04 | Admin API do Kong exposta sem RBAC | Alta | Crítica | Isolar Admin API em rede interna; RBAC Enterprise obrigatório |
| R05 | Certificados mTLS expirados sem rotação automática | Média | Alta | Integrar Kong Vault + automação de rotação (cert-manager) |
| R06 | Versão desatualizada do Kong com CVEs conhecidos | Média | Alta | Pipeline CI/CD para atualização de imagem Docker; monitorar advisories |

---

## 9. Recomendações Arquiteturais

### 9.1 Arquitetura Target com Kong

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          ZONA PÚBLICA (DMZ)                                │
│                                                                             │
│   Parceiros ──► Load Balancer ──► Kong Gateway (cluster ativo-ativo)        │
│                                    │  mTLS + Rate Limit + Correlation ID    │
│                                    │  Request Validation + ACL              │
└────────────────────────────────────┼───────────────────────────────────────┘
                                     │ (rede interna segmentada)
┌────────────────────────────────────▼───────────────────────────────────────┐
│                          ZONA INTERNA                                       │
│                                                                             │
│   Kong → API Layer ──► Hiker ──► Bulk Files ──► PostgreSQL (pagamentos)    │
│                    └──► SPB/BACEN (PIX, TED)                               │
│                    └──► Redes Adquirentes                                  │
│                                                                             │
│   VAN/SFTP ──────────────────────► Hiker (direto, sem Kong)                │
│                                                                             │
│   Kong Admin API ──────────────────────────────────────────────────────    │
│   (rede isolada)  ──► PostgreSQL Kong (config DB isolado)                  │
└────────────────────────────────────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────▼───────────────────────────────────────┐
│                       OBSERVABILIDADE                                        │
│   Prometheus ◄── Kong metrics │ SIEM ◄── Kong http-log                     │
│   Grafana Dashboard            │ Zipkin/OTEL ◄── Kong traces               │
└────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Configuração Mínima Recomendada (Kong Declarativo - deck)

```yaml
# kong.yaml — configuração declarativa (deck)
_format_version: "3.0"

services:
  - name: svc-transacoes
    url: http://api-layer:8080
    routes:
      - name: route-transacoes-post
        methods: [POST]
        paths: [/v1/transacoes]
        plugins:
          - name: mtls-auth
          - name: rate-limiting
            config:
              minute: 1000
              policy: redis
          - name: correlation-id
            config:
              header_name: X-Correlation-ID
              generator: uuid
          - name: request-transformer
            config:
              remove:
                body: [token_cartao, pan, cvv]  # NUNCA logar dados de cartão
          - name: http-log
            config:
              http_endpoint: http://siem:9200/kong-logs

      - name: route-transacoes-get
        methods: [GET]
        paths: [~/v1/transacoes/(?P<nsu>[^/]+)$]
        plugins:
          - name: mtls-auth
          - name: proxy-cache
            config:
              response_code: [200]
              request_method: [GET]
              cache_ttl: 30

  - name: svc-pix
    url: http://api-layer:8080
    routes:
      - name: route-pix-get
        methods: [GET]
        paths: [~/v1/transacoes/(?P<e2e>[^/]+)/pix$]
        plugins:
          - name: mtls-auth
          - name: correlation-id
            config:
              header_name: X-PIX-End-To-End-ID
              echo_downstream: true

  - name: svc-webhook
    url: http://api-layer:8080
    routes:
      - name: route-webhook-adquirente
        methods: [POST]
        paths: [/v1/webhooks/adquirente]
        plugins:
          - name: ip-restriction
            config:
              allow: ["10.0.0.0/8", "172.16.0.0/12"]  # IPs das adquirentes
          - name: hmac-auth
```

### 9.3 Checklist de Hardening Kong para PCI-DSS

- [ ] Desabilitar Admin API no dataplane (somente no plano de controle)
- [ ] Habilitar TLS 1.2+ exclusivamente (`ssl_protocols = TLSv1.2 TLSv1.3`)
- [ ] Remover headers de resposta que exponham versão Kong (`server_tokens = off`)
- [ ] Aplicar `request-transformer` em todas as rotas que recebem dados de cartão para mascarar campos antes do log
- [ ] Configurar `log_level = warn` em produção (evitar dump de payload nos logs de debug)
- [ ] Isolar banco de dados Kong em subnet separada do banco de pagamentos
- [ ] Rotação automática de certificados mTLS via cert-manager + Kong Vault
- [ ] Habilitar RBAC no Admin API (Enterprise) com separação de funções: `admin`, `readonly`, `ops`
- [ ] Exportar logs Kong para SIEM externo com retenção ≥ 1 ano (requisito PCI-DSS 10.7)
- [ ] Scan de vulnerabilidades na imagem Docker Kong a cada build do pipeline

---

## 10. ADRs Propostos

### ADR-K001: Kong Gateway como Único Ponto de Entrada da API Layer

**Contexto**: A arquitetura atual define uma API Layer sem especificar o componente de gateway de API. Parceiros acessam a API Layer diretamente, sem controle centralizado de autenticação, rate limiting ou logging.

**Decisão**: Adotar Kong Gateway como proxy reverso de entrada para todos os endpoints REST da API Layer. Nenhum parceiro externo acessa a API Layer diretamente.

**Consequências**:
- Autenticação, autorização e logging centralizados no Kong
- A API Layer pode focar em lógica de negócio, delegando cross-cutting concerns ao Kong
- Necessidade de gerenciar a configuração e HA do Kong como ativo crítico
- Redução do escopo PCI-DSS (Kong como único componente de borda exposto)

---

### ADR-K002: mTLS Obrigatório para Parceiros Comerciais via Kong

**Contexto**: O documento de arquitetura prevê autenticação mTLS para parceiros, mas não especifica onde esta autenticação é terminada.

**Decisão**: Kong é o ponto de terminação mTLS. Certificados de parceiros são gerenciados via Kong Admin API. A comunicação Kong → API Layer é em TLS unidirecional em rede interna segmentada.

**Consequências**:
- Simplifica a API Layer (sem lógica de validação mTLS)
- Centraliza gestão de certificados
- Exige pipeline de rotação automática de certificados (cert-manager)

---

### ADR-K003: Logs Kong com Mascaramento Obrigatório de Dados Sensíveis

**Contexto**: Kong, por padrão, pode logar o body das requisições HTTP. Dados de cartão (`token_cartao`, potencialmente `bin_cartao`) e dados pessoais (CPF) circulam no payload das transações.

**Decisão**: Aplicar plugin `request-transformer` com `remove.body` em todas as rotas que processam transações financeiras antes do plugin de logging. Auditoria de Kong se limita a metadados (consumer, rota, status HTTP, latência, correlation ID).

**Consequências**:
- Conformidade PCI-DSS e LGPD nos logs do gateway
- Logs Kong não suficientes para debug de payload — equipe de engenharia deve usar logs internos da API Layer (com controle de acesso separado)

---

### ADR-K004: Kong On-Premises (não Konnect SaaS) para Conformidade de Residência de Dados

**Contexto**: A opção Kong Konnect (plano de controle gerenciado em cloud pública) envolve tráfego de metadados de configuração e telemetria para servidores fora do Brasil.

**Decisão**: Adotar Kong Gateway Enterprise auto-hospedado em infraestrutura própria no Brasil. O plano de controle (Admin API, Kong Manager) fica na infraestrutura interna.

**Consequências**:
- Conformidade com LGPD (residência de dados no Brasil)
- Conformidade com Resolução BACEN 4.658 (controle sobre infraestrutura crítica)
- Maior responsabilidade operacional (patching, HA, backup do DB Kong)

---

## 11. Pontuação de Adequação

### 11.1 Matriz de Adequação por Dimensão

| Dimensão | Peso | Nota (0–10) | Score | Justificativa |
|---|---|---|---|---|
| **Autenticação e Autorização** | 20% | 9 | 1,80 | mTLS nativo, ACL, suporte a OAuth2/OIDC; falta RBAC granular na versão OSS |
| **Segurança PCI-DSS** | 20% | 7 | 1,40 | Atende com configuração cuidadosa; risco alto de misconfiguration de logs |
| **Disponibilidade (PIX 24×7)** | 15% | 9 | 1,35 | Cluster ativo-ativo, rolling restart — supera o requisito |
| **Desempenho** | 10% | 10 | 1,00 | Overhead Kong < 2ms — irrelevante frente ao SLO de 500ms |
| **Observabilidade** | 10% | 8 | 0,80 | Prometheus, OTEL, logging estruturado — stack completa |
| **Extensibilidade** | 10% | 9 | 0,90 | Novos parceiros via Admin API sem redeploy; custom plugins em Lua/Go |
| **Conformidade BACEN/LGPD** | 15% | 7 | 1,05 | Atende com on-premises; Konnect contraindicado |
| **Cobertura de Fluxos Batch** | 10% | 2 | 0,20 | Kong não cobre VAN/SFTP/CNAB — esperado, fora do escopo de um API gateway |

### 11.2 Score Total

| Métrica | Valor |
|---|---|
| **Score ponderado total** | **8,50 / 10** |
| **Recomendação** | ✅ **Adotar** — Kong é adequado para a camada REST do projeto |
| **Ressalva principal** | Fluxos batch (VAN/SFTP/CNAB) permanecem fora do Kong; configuração PCI exige disciplina operacional |

---

## 12. Glossário Complementar

| Termo | Definição |
|---|---|
| **Kong Gateway** | API Gateway de alto desempenho baseado em NGINX + OpenResty (LuaJIT) |
| **Kong Enterprise** | Edição comercial com RBAC, Kong Manager, Dev Portal e plugins avançados |
| **Kong Konnect** | Oferta SaaS da Kong Inc. com plano de controle gerenciado em cloud pública |
| **dataplane** | Nó Kong que processa o tráfego em tempo real (proxy) |
| **controlplane** | Componente que armazena e distribui a configuração para os dataplanes |
| **deck** | Ferramenta CLI para gestão declarativa (IaC) da configuração Kong |
| **consumer** | Entidade Kong que representa um cliente/parceiro com credenciais associadas |
| **plugin** | Extensão Kong que adiciona funcionalidade (auth, rate limit, logging, etc.) |
| **route** | Regra de roteamento Kong que mapeia uma URL para um `service` upstream |
| **service** | Abstração Kong para o serviço upstream (API Layer interna) |
| **upstream** | Conjunto de instâncias do serviço backend com balanceamento de carga |
| **rolling restart** | Reinicialização de nós Kong sem downtime, um por vez, preservando o SLA |
| **mTLS** | Mutual TLS — autenticação bidirecional por certificado (parceiro ↔ Kong) |
| **RBAC** | Role-Based Access Control — controle de acesso baseado em papéis (Admin API Kong) |
| **HMAC-auth** | Hash-based Message Authentication Code — autenticação de webhooks por assinatura de payload |
| **proxy-cache** | Plugin Kong que armazena respostas em cache para reduzir carga no upstream |
| **correlation-id** | Plugin Kong que injeta/propaga identificador único de requisição entre serviços |
| **cert-manager** | Ferramenta Kubernetes para automação de ciclo de vida de certificados TLS |
| **SIEM** | Security Information and Event Management — plataforma de centralização e análise de logs de segurança |
