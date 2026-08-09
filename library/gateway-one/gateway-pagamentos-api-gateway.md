# Avaliação de Arquitetura — AWS API Gateway como Catálogo Central de Serviços
## Gateway de Pagamentos — Plataforma de Processamento Financeiro

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Rascunho |
| Domínio | Meios de Pagamento |
| Referência | [gateway-de-pagamentos.md](./gateway-de-pagamentos.md) · [gateway-pagamentos-arquitetura-software.md](./gateway-pagamentos-arquitetura-software.md) |
| Conformidade | BACEN / SPB / PIX / CNAB 240 / CNAB 400 / PCI-DSS |

---

## Índice

1. [Motivação e Contexto](#1-motivação-e-contexto)
2. [O Problema: Ausência de um Catálogo Central de APIs](#2-o-problema-ausência-de-um-catálogo-central-de-apis)
3. [Proposta: AWS API Gateway como Plano de Controle Central](#3-proposta-aws-api-gateway-como-plano-de-controle-central)
4. [Visão Arquitetural com API Gateway](#4-visão-arquitetural-com-api-gateway)
5. [Mapeamento do Catálogo de Serviços](#5-mapeamento-do-catálogo-de-serviços)
6. [Capacidades Técnicas Relevantes](#6-capacidades-técnicas-relevantes)
7. [Segurança e Compliance com API Gateway](#7-segurança-e-compliance-com-api-gateway)
8. [Modelo de Custo AWS API Gateway](#8-modelo-de-custo-aws-api-gateway)
9. [Análise de Custo para o Gateway de Pagamentos](#9-análise-de-custo-para-o-gateway-de-pagamentos)
10. [Comparativo Arquitetural: Antes e Depois](#10-comparativo-arquitetural-antes-e-depois)
11. [Decisões Arquiteturais (ADRs)](#11-decisões-arquiteturais-adrs)
12. [Riscos e Mitigações](#12-riscos-e-mitigações)
13. [Recomendação Final](#13-recomendação-final)
14. [Glossário Complementar](#14-glossário-complementar)

---

## 1. Motivação e Contexto

O **Gateway de Pagamentos** é uma plataforma de infraestrutura financeira que conecta parceiros comerciais (bancos, fintechs, varejistas, subadquirentes) às redes de processamento do mercado financeiro brasileiro, suportando **cartão de crédito**, **cartão de débito**, **boleto registrado**, **PIX**, **TED** e **DOC** em conformidade com as normas do BACEN.

A arquitetura atual expõe uma **API Layer** (camada de API REST) que atende às integrações em tempo real com parceiros. À medida que o catálogo de serviços da empresa cresce — abrangendo múltiplos componentes como **Hiker**, **configServerFiles**, **Bulk Files Pipeline**, **Dashboard Operacional** e integrações externas (VAN, redes adquirentes, SPB/BACEN) — surgem desafios estruturais de:

- **Governança**: sem um ponto central de controle, cada serviço implementa autenticação, autorização, rate limiting e logging de forma independente e inconsistente.
- **Descoberta de serviços**: parceiros e times internos não possuem um catálogo unificado dos endpoints disponíveis.
- **Observabilidade**: métricas de chamadas de API fragmentadas entre serviços.
- **Custo operacional**: overhead de implementar cross-cutting concerns repetidamente em cada serviço.

Este documento avalia a adoção do **AWS API Gateway** como a ferramenta central de catálogo e proxy de chamadas de APIs para todo o portfólio de serviços da plataforma.

---

## 2. O Problema: Ausência de um Catálogo Central de APIs

### 2.1 Situação Atual

```
Parceiros Externos
      │
      ├── Chamada direta → API Layer (REST interno)
      ├── Arquivo SFTP   → VAN / SFTP (sem API)
      └── Dashboard      → WebSocket direto

Times Internos
      ├── Hiker          → Chamada interna direta
      ├── configServerFiles → Chamada interna direta
      └── Bulk Files     → Integração ponto a ponto
```

### 2.2 Consequências da Ausência de um API Gateway Central

| Problema | Impacto |
|---|---|
| **Autenticação distribuída** | Cada serviço implementa validação de API Key / mTLS de forma independente — risco de inconsistência e brecha |
| **Sem rate limiting unificado** | Um parceiro mal configurado pode saturar um serviço específico sem throttling global |
| **Rastreabilidade fragmentada** | Logs de acesso espalhados em múltiplos serviços, sem correlação de request-id entre chamadas |
| **Ausência de contrato formal** | Sem schema OpenAPI centralizado, a documentação diverge da implementação |
| **Onboarding de parceiros custoso** | Cada novo parceiro requer configuração manual em múltiplos serviços |
| **Sem versionamento de API governado** | Mudanças em `/v1/transacoes` não têm política de deprecação centralizada |

---

## 3. Proposta: AWS API Gateway como Plano de Controle Central

### 3.1 Conceito

O **AWS API Gateway** atua como o **único ponto de entrada** para todas as chamadas de API da plataforma — tanto para parceiros externos quanto para integrações internas entre serviços. Ele assume os **cross-cutting concerns** de toda a camada de API:

```
                    ┌─────────────────────────────────────────────┐
                    │           AWS API GATEWAY                    │
                    │                                             │
                    │  ┌─────────────┐   ┌──────────────────┐   │
                    │  │  Auth/AuthZ │   │  Rate Limiting   │   │
                    │  │  (Cognito / │   │  (Throttling por │   │
                    │  │   mTLS/JWT) │   │   parceiro/rota) │   │
                    │  └─────────────┘   └──────────────────┘   │
                    │                                             │
                    │  ┌─────────────┐   ┌──────────────────┐   │
                    │  │  Catálogo   │   │  Observabilidade │   │
                    │  │  OpenAPI    │   │  (CloudWatch /   │   │
                    │  │  (Swagger)  │   │   X-Ray)         │   │
                    │  └─────────────┘   └──────────────────┘   │
                    │                                             │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  Roteamento para Backends           │  │
                    │  │  (Lambda / HTTP / VPC Link / Mock)  │  │
                    │  └─────────────────────────────────────┘  │
                    └─────────────────────────────────────────────┘
                         │              │              │
                    API Layer      configServer    Dashboard
                    (Transações)     Files         WebSocket
```

### 3.2 Tipos de API Gateway na AWS

| Tipo | Melhor para | Relevância para o Gateway de Pagamentos |
|---|---|---|
| **REST API** | APIs com controles avançados (uso plans, caching, validação de request) | ✅ **Principal** — endpoints transacionais `/v1/transacoes`, `/v1/arquivos` |
| **HTTP API** | APIs simples de alta performance com baixo custo | ✅ **Secundário** — callbacks internos, webhooks de adquirentes |
| **WebSocket API** | Comunicação bidirecional, streaming | ✅ **Dashboard** — feed de eventos do Hiker em tempo real |

---

## 4. Visão Arquitetural com API Gateway

### 4.1 Diagrama Completo

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         GATEWAY DE PAGAMENTOS — COM AWS API GATEWAY              │
│                                                                                  │
│  ┌─────────────┐    ┌────────────────────────────────────────────────────────┐  │
│  │  Parceiros  │    │                 AWS API GATEWAY                         │  │
│  │             │    │                                                         │  │
│  │  Bancos     │───►│  REST API          HTTP API         WebSocket API       │  │
│  │  Fintechs   │    │  /v1/transacoes    /webhooks        /dashboard/events   │  │
│  │  Varejistas │    │  /v1/arquivos      /callbacks       /hiker/stream       │  │
│  │  Subadquir. │    │  /v1/pix                                                │  │
│  └─────────────┘    │  /v1/estornos                                           │  │
│                     │  /admin/config                                          │  │
│  ┌─────────────┐    │  /admin/parceiros                                       │  │
│  │  Times      │    └──────────────────────────┬──────────────────────────────┘  │
│  │  Internos   │───►                           │                                  │
│  └─────────────┘              ┌────────────────┼──────────────────┐               │
│                               │                │                  │               │
│                      ┌────────▼──────┐ ┌───────▼──────┐ ┌────────▼───────┐      │
│                      │  API Layer    │ │configServer  │ │  Dashboard     │      │
│                      │  (Transações) │ │   Files      │ │  Operacional   │      │
│                      └──────┬────────┘ └───────┬──────┘ └────────────────┘      │
│                             │                  │                                  │
│                      ┌──────▼──────────────────▼──┐                              │
│                      │       Core Platform         │                              │
│                      │  Hiker ── Bulk Files        │                              │
│                      │  PostgreSQL (fato_transacao) │                              │
│                      └─────────────────────────────┘                              │
│                                    │                                               │
└────────────────────────────────────┼───────────────────────────────────────────────┘
                                     │
              ┌──────────────────────┼───────────────────────┐
              ▼                      ▼                        ▼
     Redes Adquirentes        SPB / BACEN / PIX         VAN Febraban
     (VISA, Mastercard, ELO) (Sistema Pagamentos BR)   (SFTP / MQ)
```

### 4.2 Camadas Redefinidas com API Gateway

```
┌──────────────────────────────────────────────────────────┐
│                   CAMADA DE ENTRADA                       │
│                                                           │
│          ┌────────────────────────────────────┐          │
│          │       AWS API GATEWAY               │          │
│          │  (Plano de Controle Unificado)      │          │
│          │  Auth · Throttle · Catalog · Log    │          │
│          └────────────────────────────────────┘          │
│                                                           │
│   VAN (SFTP/MQ)  ←→  fora do API Gateway (binário)      │
└───────────────────────────────┬──────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────┐
│               CAMADA DE PROCESSAMENTO                     │
│   Hiker · configServerFiles · Bulk Files Pipeline         │
└───────────────────────────────┬──────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────┐
│                  CAMADA DE DADOS                          │
│   fato_transacao · dim_* · hiker_auditoria · eventos      │
└──────────────────────────────────────────────────────────┘
```

---

## 5. Mapeamento do Catálogo de Serviços

### 5.1 Catálogo Completo de APIs no AWS API Gateway

| API Stage | Método | Recurso | Backend | Descrição | Tipo Gateway |
|---|---|---|---|---|---|
| `v1` | `POST` | `/transacoes` | API Layer | Submeter nova transação (cartão, PIX, boleto) | REST API |
| `v1` | `GET` | `/transacoes/{nsu}` | API Layer | Consultar transação por NSU | REST API |
| `v1` | `GET` | `/transacoes/{e2e_id}/pix` | API Layer | Consultar transação PIX por E2E ID | REST API |
| `v1` | `POST` | `/transacoes/{id}/estorno` | API Layer | Solicitar estorno | REST API |
| `v1` | `GET` | `/arquivos/{arquivo_id}/status` | API Layer (Hiker) | Status de processamento Hiker | REST API |
| `v1` | `POST` | `/arquivos/upload` | API Layer (Hiker) | Upload de arquivo CNAB/PIX via API | REST API |
| `v1` | `POST` | `/webhooks/adquirente` | API Layer | Receber retorno da rede adquirente | HTTP API |
| `v1` | `GET` | `/pix/chaves/{chave}` | API Layer | Consultar chave PIX | REST API |
| `admin` | `GET` | `/config/layouts` | configServerFiles | Listar configurações de layout | REST API |
| `admin` | `POST` | `/config/layouts` | configServerFiles | Criar nova regra de layout | REST API |
| `admin` | `GET` | `/config/layouts/{parceiro}` | configServerFiles | Regra de layout por parceiro | REST API |
| `admin` | `GET` | `/parceiros` | API Layer | Listar parceiros ativos | REST API |
| `admin` | `POST` | `/parceiros` | API Layer | Onboarding de novo parceiro | REST API |
| `ws` | `$connect` | `/dashboard/events` | Dashboard | Conectar ao feed de eventos | WebSocket API |
| `ws` | `$default` | `/hiker/stream` | Dashboard (Hiker) | Stream de auditoria do Hiker | WebSocket API |

### 5.2 Planos de Uso por Perfil de Parceiro

| Plano | Parceiros | Requisições/s | Burst | Cota Mensal |
|---|---|---|---|---|
| **Premium** | Grandes bancos, redes adquirentes | 1.000 req/s | 2.000 | Ilimitado |
| **Standard** | Fintechs, subadquirentes médios | 200 req/s | 500 | 10M |
| **Basic** | Varejistas, parceiros pequenos | 50 req/s | 100 | 1M |
| **Internal** | Times internos, automações | 500 req/s | 1.000 | Ilimitado |

---

## 6. Capacidades Técnicas Relevantes

### 6.1 Autenticação e Autorização

| Mecanismo | Aplicação no Gateway de Pagamentos | Disponível em |
|---|---|---|
| **API Key** | Identificação de parceiro por `x-api-key` no header | REST + HTTP |
| **mTLS (mutual TLS)** | Canal seguro com certificado de cliente — parceiros certificados | REST + HTTP |
| **AWS Cognito (JWT)** | Tokens OAuth2/OIDC para dashboard web e APIs administrativas | REST + HTTP |
| **Lambda Authorizer** | Validação customizada de tokens proprietários / certificados VAN | REST + HTTP |
| **IAM Authorization** | Acesso de serviços AWS internos (Lambda, Step Functions) | REST + HTTP |

**Alinhamento com a arquitetura existente**: A [Seção 10.4 de controle de acesso](./gateway-pagamentos-arquitetura-software.md) define mTLS + API Key como padrão para parceiros — o AWS API Gateway suporta **ambos nativamente**, eliminando a implementação custom atual.

### 6.2 Validação de Request (Model Validation)

O AWS API Gateway REST API permite definir **modelos JSON Schema** que validam automaticamente o payload antes de acionar o backend:

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "TransacaoPIX",
  "type": "object",
  "required": ["valor", "chave_pix", "descricao"],
  "properties": {
    "valor": { "type": "number", "minimum": 0.01 },
    "chave_pix": { "type": "string", "minLength": 1 },
    "descricao": { "type": "string", "maxLength": 140 },
    "end_to_end_id": {
      "type": "string",
      "pattern": "^E[0-9]{8}[0-9]{8}T[0-9]{9}$"
    }
  }
}
```

Benefício direto: rejeição de payloads malformados **antes** de consumir recursos do backend — latência zero e redução de carga no Hiker para pré-validação de formato.

### 6.3 Throttling e Rate Limiting

```
Parceiro Banco A (Premium)
    │  1.000 req/s → API Gateway throttle stage-level
    │  → POST /v1/transacoes → backend API Layer
    │
    │  Se exceder → HTTP 429 Too Many Requests
    │              + header Retry-After
```

- **Stage-level throttling**: limite global por ambiente (`prod`, `homolog`)
- **Method-level throttling**: limites específicos por rota (ex: `/pix` mais restrito que `/consultas`)
- **Usage Plan throttling**: por API Key de parceiro — garante isolamento entre parceiros

### 6.4 Caching

Para rotas de consulta estável (ex: `configServerFiles`), o API Gateway oferece **cache por TTL** no nível do estágio:

| Rota | Cache TTL sugerido | Benefício |
|---|---|---|
| `GET /config/layouts/{parceiro}` | 300s (5 min) | Reduz chamadas ao configServerFiles — regras mudam raramente |
| `GET /parceiros` | 60s | Lista de parceiros ativos muda com baixa frequência |
| `GET /transacoes/{nsu}` | **Sem cache** | Status de transação muda — sempre buscar estado atual |
| `GET /transacoes/{e2e_id}/pix` | **Sem cache** | Idem — status PIX em tempo real |

### 6.5 Transformação de Payload (Mapping Templates)

O API Gateway suporta transformação de request/response com **VTL (Velocity Template Language)** — permite:

- Adaptar o formato de entrada do parceiro para o contrato interno do backend (ex: campo `chave` → `chave_pix`)
- Mascarar campos sensíveis na resposta (nunca expor `token_cartao` interno — apenas `bin_cartao` + `final_cartao`)
- Normalizar erros de backend em envelope padrão de resposta de erro da plataforma

### 6.6 Integração com Backends

| Tipo de Integração | Uso no Gateway de Pagamentos |
|---|---|
| **HTTP Proxy** | API Layer existente (transações, estornos, consultas) |
| **Lambda Proxy** | Funções de validação customizada, Hiker stateless por arquivo |
| **VPC Link** | Backends em VPC privada (PostgreSQL-facing services) sem exposição pública |
| **Mock** | Respostas fixas para parceiros em sandbox / testes de integração |
| **AWS Service** | Integração direta com SQS (fila de arquivos), S3 (upload de arquivos CNAB) |

---

## 7. Segurança e Compliance com API Gateway

### 7.1 Alinhamento com Requisitos PCI-DSS

| Requisito PCI-DSS | Como o API Gateway contribui |
|---|---|
| **Req. 1 — Firewall de rede** | WAF (AWS WAF) acoplado ao API Gateway — regras de bloqueio de IPs, SQLi, XSS |
| **Req. 2 — Não usar defaults de segurança** | TLS 1.2+ obrigatório; políticas de segurança de TLS configuráveis |
| **Req. 4 — Criptografia em trânsito** | TLS 1.2+ em toda comunicação pelo API Gateway por padrão |
| **Req. 7 — Acesso por necessidade** | Resource Policies + IAM controlam quais serviços podem chamar quais rotas |
| **Req. 10 — Logs de acesso** | Access Logs para CloudWatch — todos os requests/responses logados com IP, user, rota, latência |

### 7.2 Alinhamento com BACEN / Resolução 4.658

| Requisito | Implementação via API Gateway |
|---|---|
| **Identificação de acesso** | Logs detalhados com `requestId`, `caller`, `sourceIp`, `userAgent` |
| **Rastreabilidade** | `X-Amzn-Trace-Id` propagado automaticamente para correlação com AWS X-Ray |
| **Controle de acesso** | Autorizers customizados por rota para granularidade de permissão |
| **Disponibilidade 24×7 (PIX)** | SLA de 99,95% do API Gateway gerenciado pela AWS — sem janela de manutenção |

### 7.3 Proteção com AWS WAF

```
Internet
    │
    ▼
AWS WAF (acoplado ao API Gateway)
    │  ┌─ Block: SQL Injection rules
    │  ├─ Block: XSS rules
    │  ├─ Block: IPs bloqueados (fraud list)
    │  ├─ Rate-based rule: max 1000 req/5min por IP
    │  └─ Allow: IPs de parceiros homologados (allowlist)
    │
    ▼
AWS API Gateway
    │
    ▼
Backends (API Layer, Hiker, etc.)
```

### 7.4 Custom Domain e Certificado

```
https://api.gateway-pagamentos.com.br/v1/transacoes
        │
        └── ACM Certificate (AWS Certificate Manager) — TLS 1.2+
            └── Custom Domain Name no API Gateway
                └── Route 53 (DNS gerenciado)
```

Suporte a **múltiplos domínios** por stage — ex: `api.gateway-pagamentos.com.br` (produção), `sandbox.gateway-pagamentos.com.br` (integração).

---

## 8. Modelo de Custo AWS API Gateway

### 8.1 Tabela de Preços (Região us-east-1 / sa-east-1 — referência 2024)

#### REST API

| Faixa de Chamadas (por mês) | Preço por 1M chamadas |
|---|---|
| Primeiros 333 milhões | US$ 3,50 |
| Próximos 667 milhões | US$ 2,80 |
| Acima de 1 bilhão | US$ 2,38 |

> **Cache (opcional)**: de US$ 0,020/h (0,5 GB) a US$ 3,84/h (237 GB)
> **Data Transfer Out**: US$ 0,09/GB (primeiros 10 TB/mês)

#### HTTP API — ~71% mais barato que REST API

| Faixa de Chamadas (por mês) | Preço por 1M chamadas |
|---|---|
| Primeiros 300 milhões | US$ 1,00 |
| Acima de 300 milhões | US$ 0,90 |

#### WebSocket API

| Dimensão | Preço |
|---|---|
| Por 1M de mensagens | US$ 1,00 |
| Por 1M de minutos de conexão | US$ 0,25 |

### 8.2 Free Tier (Nível Gratuito Permanente)

| Tipo | Free Tier por Mês |
|---|---|
| **REST API** | 1 milhão de chamadas gratuitas/mês — **primeiros 12 meses** |
| **HTTP API** | 1 milhão de chamadas gratuitas/mês — **primeiros 12 meses** |
| **WebSocket API** | 1 milhão de mensagens + 750.000 min de conexão/mês — **primeiros 12 meses** |

---

## 9. Análise de Custo para o Gateway de Pagamentos

### 9.1 Cenário Base — Plataforma em Crescimento (Fase Inicial)

**Premissas**:
- 5 milhões de chamadas API REST/mês (transações + consultas)
- 2 milhões de chamadas HTTP API/mês (webhooks de adquirentes + callbacks)
- 500.000 mensagens WebSocket/mês (dashboard operacional)
- Cache desabilitado (fase inicial)

| Componente | Volume | Cálculo | Custo Mensal (USD) |
|---|---|---|---|
| REST API | 5M chamadas | 5 × US$ 3,50 | **US$ 17,50** |
| HTTP API | 2M chamadas | 2 × US$ 1,00 | **US$ 2,00** |
| WebSocket (mensagens) | 0,5M msg | 0,5 × US$ 1,00 | **US$ 0,50** |
| WebSocket (conexões) | 100K min | 0,1 × US$ 0,25 | **US$ 0,025** |
| Data Transfer Out | ~2 GB | 2 × US$ 0,09 | **US$ 0,18** |
| **Total Estimado** | | | **~US$ 20,20/mês** |

### 9.2 Cenário de Escala — Operação em Produção Plena

**Premissas**:
- 100 milhões de chamadas REST API/mês
- 20 milhões de chamadas HTTP API/mês
- 10 milhões de mensagens WebSocket/mês
- Cache habilitado para configServerFiles (0,5 GB, 730h/mês)

| Componente | Volume | Cálculo | Custo Mensal (USD) |
|---|---|---|---|
| REST API | 100M chamadas | 100 × US$ 3,50 | **US$ 350,00** |
| HTTP API | 20M chamadas | 20 × US$ 1,00 | **US$ 20,00** |
| WebSocket (mensagens) | 10M msg | 10 × US$ 1,00 | **US$ 10,00** |
| WebSocket (conexões) | 5M min | 5 × US$ 0,25 | **US$ 1,25** |
| Cache (0,5 GB × 730h) | 730h | 730 × US$ 0,020 | **US$ 14,60** |
| Data Transfer Out | ~50 GB | 50 × US$ 0,09 | **US$ 4,50** |
| **Total Estimado** | | | **~US$ 400,35/mês** |

### 9.3 Contexto de Custo — Comparativo

| Alternativa | Custo Mensal Estimado | Observações |
|---|---|---|
| **AWS API Gateway (HTTP API)** | US$ 2–20 (fase inicial) | Custo quase zero no início; escala linear |
| **AWS API Gateway (REST API)** | US$ 20–400 (escala) | Funcionalidades avançadas (cache, validação, usage plans) |
| **Kong Gateway (self-hosted)** | US$ 200–800 (infra EC2) | Requer instâncias dedicadas + operação |
| **Apigee (Google)** | US$ 500–2.000+ | Licença enterprise; funcionalidades avançadas |
| **AWS API Gateway + 12m Free Tier** | **US$ 0** (até 1M req/mês) | Custo zero para MVP e fase de validação |

> **Conclusão de custo**: Para o estágio inicial da plataforma, o AWS API Gateway representa custo **próximo de zero** — especialmente com HTTP API para rotas internas e webhooks. O custo somente se torna relevante (> US$ 400/mês) quando a plataforma atinge operação em escala com > 100M chamadas/mês, patamar onde o valor gerado pela plataforma justifica amplamente o investimento.

---

## 10. Comparativo Arquitetural: Antes e Depois

### 10.1 Antes (sem API Gateway central)

| Aspecto | Situação |
|---|---|
| **Autenticação** | Implementada individualmente em cada serviço (API Layer, configServerFiles, Dashboard) |
| **Rate Limiting** | Ausente ou implementado por serviço com bibliotecas diferentes |
| **Catálogo de APIs** | Documentação manual, geralmente desatualizada |
| **Observabilidade** | Logs em múltiplos serviços sem correlação de request-id |
| **Onboarding** | Configuração manual em cada backend para cada novo parceiro |
| **Versionamento** | Sem política centralizada — `/v1` e `/v2` coexistem sem deprecação formal |
| **Segurança** | WAF e TLS configurados por serviço |

### 10.2 Depois (com AWS API Gateway central)

| Aspecto | Situação com API Gateway |
|---|---|
| **Autenticação** | Centralizada no API Gateway — mTLS + API Key + Cognito JWT |
| **Rate Limiting** | Usage Plans por parceiro com throttling granular por rota |
| **Catálogo de APIs** | OpenAPI/Swagger exportado automaticamente do API Gateway |
| **Observabilidade** | CloudWatch + X-Ray — trace distribuído com `X-Amzn-Trace-Id` unificado |
| **Onboarding** | Novo parceiro = nova API Key + associação a Usage Plan no API Gateway |
| **Versionamento** | Stages (`v1`, `v2`) com canary deployments e rollback imediato |
| **Segurança** | AWS WAF acoplado + TLS 1.2+ + Resource Policies centralizados |

### 10.3 Diagrama de Fluxo: Transação PIX com API Gateway

```
Parceiro (Fintech A)
    │
    │  POST https://api.gateway-pagamentos.com.br/v1/transacoes
    │  Headers: x-api-key: <key>, Content-Type: application/json
    │  Body: { "valor": 150.00, "chave_pix": "cpf@email.com", ... }
    │
    ▼
AWS WAF ──► [regras XSS/SQLi/IP bloqueado] ──► ALLOW
    │
    ▼
AWS API Gateway (REST API)
    ├── Validação de API Key → Usage Plan "Standard" ✓
    ├── Throttling: 200 req/s → dentro do limite ✓
    ├── Model Validation (JSON Schema) → payload válido ✓
    ├── Access Log → CloudWatch (requestId, ip, user, rota, timestamp)
    └── Route: POST /v1/transacoes → HTTP Proxy → API Layer interno
    │
    ▼
API Layer (backend interno)
    ├── Valida regras de negócio
    ├── Hiker valida PIX JSON
    └── INSERT fato_transacao (status: RECEBIDA)
    │
    ▼
SPB / BACEN
    │
    ◄── retorno SPB
    │
API Layer ──► status: AUTORIZADA ──► fato_transacao
    │
    ▼
AWS API Gateway ──► resposta ao Parceiro
    {
      "transacao_id": "uuid",
      "status": "AUTORIZADA",
      "end_to_end_id": "E12345678...",
      "timestamp": "2024-01-15T14:23:11Z"
    }
```

---

## 11. Decisões Arquiteturais (ADRs)

### ADR-007: AWS API Gateway como Plano de Controle Único

**Contexto**: A plataforma possui múltiplos serviços (API Layer, configServerFiles, Dashboard, Hiker) sem um ponto centralizado de controle de acesso, throttling e observabilidade. Cada serviço implementa cross-cutting concerns de forma independente.

**Decisão**: Adotar o **AWS API Gateway** como único ponto de entrada para todas as chamadas de API — tanto de parceiros externos quanto de integrações internas entre serviços.

**Consequências**:
- ✅ Cross-cutting concerns (auth, throttle, logging) implementados uma única vez
- ✅ Catálogo de serviços disponível via exportação OpenAPI automática
- ✅ Onboarding de parceiros simplificado (API Key + Usage Plan)
- ⚠️ Latência adicional de ~1–3ms por chamada (overhead do proxy — aceitável para o SLA de < 500ms P95)
- ⚠️ Vendor lock-in AWS mitigado pelo padrão OpenAPI (contrato portável)

---

### ADR-008: REST API para Endpoints Transacionais, HTTP API para Webhooks

**Contexto**: O AWS API Gateway oferece dois tipos principais de API com diferentes conjuntos de funcionalidades e preços. REST API é ~3,5x mais caro que HTTP API, mas oferece usage plans, caching e model validation.

**Decisão**: Usar **REST API** para endpoints transacionais críticos (`/v1/transacoes`, `/v1/arquivos`, `/v1/pix`) e **HTTP API** para endpoints de menor criticidade (webhooks, callbacks internos).

**Consequências**:
- ✅ Funcionalidades avançadas (usage plans, caching, validação) onde há mais valor
- ✅ Custo otimizado para rotas de alto volume mas baixa complexidade
- ⚠️ Dois tipos de gateway a operar — equipe precisa conhecer as diferenças de configuração

---

### ADR-009: VPC Link para Backends Privados

**Contexto**: Os backends (API Layer, configServerFiles) devem rodar em VPC privada sem exposição pública direta, em conformidade com PCI-DSS e BACEN Resolução 4.658.

**Decisão**: Usar **VPC Link** do API Gateway para rotear chamadas para backends em sub-redes privadas sem exposição à internet.

**Consequências**:
- ✅ Backends nunca expostos publicamente — tráfego interno à AWS
- ✅ Conformidade PCI-DSS: controle de acesso em nível de rede
- ⚠️ Custo adicional de Network Load Balancer para VPC Link (~US$ 18/mês por NLB)

---

### ADR-010: AWS WAF Acoplado ao API Gateway para Proteção PCI-DSS

**Contexto**: PCI-DSS Req. 6.4 exige proteção de aplicação web com WAF para todos os sistemas que processam dados de pagamento.

**Decisão**: Acoplar **AWS WAF** ao API Gateway com regras gerenciadas AWS (Core Rule Set, SQL Injection, Known Bad Inputs) + regras customizadas de allowlist por IP de parceiro.

**Consequências**:
- ✅ Conformidade PCI-DSS Req. 6.4 nativa
- ✅ Proteção gerenciada sem overhead operacional de manutenção de regras base
- ⚠️ Custo adicional: ~US$ 5/mês (WebACL) + US$ 1/M requests inspecionados

---

## 12. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| **Latência adicional do proxy** | Alta | Baixo | Overhead de 1–3ms — dentro do SLA P95 < 500ms; monitorar com X-Ray |
| **Vendor lock-in AWS** | Média | Médio | Contrato OpenAPI portável; backends agnósticos de cloud |
| **Indisponibilidade do API Gateway** | Baixa | Alto | SLA AWS 99,95% — superior à meta de 99,9% da plataforma; multi-region para PIX |
| **Custo surpresa em pico de tráfego** | Média | Baixo | Throttling no próprio API Gateway previne burst não autorizado; Budget Alerts no AWS |
| **Configuração incorreta de autorizer** | Média | Alto | Testes de contrato automatizados por parceiro; env de sandbox obrigatório antes de prod |
| **Rate limit apertado bloqueando parceiro legítimo** | Média | Médio | Monitoramento de 429s por API Key no CloudWatch; alertas antes de atingir limite |

---

## 13. Recomendação Final

### 13.1 Adoção Recomendada: ✅ AWS API Gateway

O AWS API Gateway é **fortemente recomendado** como catálogo central e plano de controle de APIs para o Gateway de Pagamentos pelos seguintes motivos:

| Critério | Avaliação |
|---|---|
| **Custo** | ✅ Próximo de zero no início (free tier + HTTP API); escala linear com o volume |
| **Segurança** | ✅ mTLS, API Key, Cognito JWT, WAF, TLS 1.2+ — cobre todos os requisitos PCI-DSS e BACEN |
| **Conformidade** | ✅ Access logs, X-Ray tracing, SLA 99,95% — atende BACEN Resolução 4.658 |
| **Operacional** | ✅ Serviço gerenciado — sem patches, sem capacity planning, sem infra de gateway |
| **Extensibilidade** | ✅ Novos serviços adicionados ao catálogo sem impacto nos existentes |
| **Developer Experience** | ✅ Exportação automática de OpenAPI para documentação de parceiros |
| **Time-to-market** | ✅ Configurável via IaC (Terraform/CDK) — em produção em dias, não meses |

### 13.2 Roadmap de Adoção Sugerido

| Fase | Ações | Prazo |
|---|---|---|
| **Fase 1 — Fundação** | Criar REST API no API Gateway para `/v1/transacoes` e `/v1/arquivos`; migrar autenticação mTLS + API Key; habilitar Access Logs no CloudWatch | 2–3 semanas |
| **Fase 2 — Expansão do Catálogo** | Adicionar rotas de configServerFiles (`/admin/config`), parceiros (`/admin/parceiros`); criar Usage Plans por segmento de parceiro | 2–3 semanas |
| **Fase 3 — Webhooks e WebSocket** | Criar HTTP API para webhooks de adquirentes; criar WebSocket API para Dashboard operacional | 1–2 semanas |
| **Fase 4 — Segurança Avançada** | Acoplar AWS WAF com Core Rule Set + allowlist de IPs de parceiros; implementar VPC Link para backends privados | 1–2 semanas |
| **Fase 5 — Observabilidade** | Habilitar AWS X-Ray tracing; criar dashboards CloudWatch por parceiro e por rota; configurar alertas de 4xx/5xx e latência P95 | 1 semana |
| **Fase 6 — Cache e Otimização** | Habilitar cache para rotas de configServerFiles; tunar Usage Plans com base em dados reais; exportar OpenAPI para portal de desenvolvedores | 1 semana |

### 13.3 Resumo Executivo de Custo

> Para uma plataforma de pagamentos em crescimento, o **AWS API Gateway representa um custo marginal irrisório** em relação ao valor entregue:
>
> - **Fase inicial (< 10M req/mês)**: custo de **US$ 10–40/mês** — literalmente próximo de zero para uma infraestrutura financeira.
> - **Operação em escala (100M req/mês)**: custo de **~US$ 400/mês** — equivale a um único dia de custo de EC2 de uma alternativa self-hosted como Kong.
> - **Free Tier**: durante os **primeiros 12 meses**, até 1M chamadas/mês são **completamente gratuitas** — ideal para o período de validação da plataforma.
>
> O custo do API Gateway é marginal comparado ao custo de implementar e manter os mesmos cross-cutting concerns de forma distribuída em cada serviço.

---

## 14. Glossário Complementar

| Termo | Definição |
|---|---|
| **API Gateway** | Serviço que atua como ponto de entrada único para APIs — gerencia autenticação, throttling, roteamento e observabilidade |
| **Usage Plan** | Configuração de cota e throttling no API Gateway associada a um conjunto de API Keys |
| **API Key** | Identificador de cliente para o API Gateway — associado a um Usage Plan para controle de acesso e cota |
| **Stage** | Ambiente de deployment no API Gateway (ex: `prod`, `homolog`, `sandbox`) |
| **Canary Deployment** | Técnica de deploy gradual — o API Gateway suporta rotear % do tráfego para nova versão antes do rollout completo |
| **VPC Link** | Conexão privada entre o API Gateway e backends em VPC privada da AWS — sem exposição pública |
| **Lambda Authorizer** | Função Lambda customizada que implementa lógica de autorização chamada pelo API Gateway antes de cada request |
| **Model Validation** | Validação automática de payload no API Gateway com base em JSON Schema antes de acionar o backend |
| **WAF** | Web Application Firewall — filtra tráfego HTTP/HTTPS por regras de segurança (SQLi, XSS, rate limits) |
| **X-Ray** | Serviço AWS de rastreamento distribuído — permite visualizar o fluxo de uma requisição por todos os componentes |
| **CloudWatch** | Serviço AWS de observabilidade — logs, métricas, alarmes e dashboards |
| **mTLS** | Mutual TLS — autenticação bidirecional por certificado; tanto o servidor quanto o cliente apresentam certificados |
| **HTTP API** | Tipo de API Gateway otimizado para performance e custo baixo (~71% mais barato que REST API) |
| **REST API** | Tipo de API Gateway com funcionalidades avançadas (usage plans, caching, model validation, API Keys) |
| **WebSocket API** | Tipo de API Gateway para comunicação bidirecional persistente — ideal para dashboards em tempo real |
| **VTL** | Velocity Template Language — linguagem usada no API Gateway para transformação de payload (mapping templates) |
| **ACM** | AWS Certificate Manager — gerencia certificados TLS/SSL para domínios customizados no API Gateway |
| **Throttling** | Limitação da taxa de requisições para proteger backends de sobrecarga |
| **Free Tier** | Nível gratuito da AWS — até 1M chamadas REST/HTTP API por mês durante os primeiros 12 meses |
