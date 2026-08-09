# Documento de Arquitetura de Software
## Gateway de Pagamentos — Plataforma de Processamento Financeiro

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Rascunho |
| Domínio | Meios de Pagamento |
| Conformidade | BACEN / SPB / PIX / CNAB 240 / CNAB 400 / PCI-DSS |

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Escopo e Objetivos](#2-escopo-e-objetivos)
3. [Stakeholders](#3-stakeholders)
4. [Restrições e Conformidade](#4-restrições-e-conformidade)
5. [Visão Arquitetural](#5-visão-arquitetural)
6. [Componentes Principais](#6-componentes-principais)
7. [Modelo de Dados](#7-modelo-de-dados)
8. [Fluxos de Negócio](#8-fluxos-de-negócio)
9. [Integrações Externas](#9-integrações-externas)
10. [Segurança e Compliance](#10-segurança-e-compliance)
11. [Atributos de Qualidade](#11-atributos-de-qualidade)
12. [Decisões Arquiteturais (ADRs)](#12-decisões-arquiteturais-adrs)
13. [Glossário](#13-glossário)

---

## 1. Visão Geral

O **Gateway de Pagamentos** é uma plataforma de infraestrutura financeira que atua como intermediário entre parceiros comerciais (bancos, fintechs, varejistas e subadquirentes) e as redes de processamento do mercado financeiro brasileiro. A solução suporta os principais instrumentos de pagamento regulados pelo BACEN: **cartão de crédito**, **cartão de débito**, **boleto registrado** e **PIX**, além de **TED** e **DOC**.

A arquitetura é projetada para ser **confiável**, **auditável** e **regulatoriamente conforme**, estabelecendo um canal seguro de comunicação interbancária (VAN) e expondo APIs modernas para integração com parceiros.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GATEWAY DE PAGAMENTOS                               │
│                                                                             │
│   ┌──────────┐   ┌─────────────────────────────────────────────────────┐   │
│   │ Parceiros│   │                   Core Platform                     │   │
│   │          │   │                                                     │   │
│   │ Bancos   │◄──│  API Layer  ──►  Hiker  ──►  Bulk Files Pipeline   │   │
│   │ Fintechs │   │                    │                                │   │
│   │ Varejistas│  │  VAN / SFTP        │                                │   │
│   └──────────┘   │                   ▼                                 │   │
│                  │            configServerFiles                        │   │
│                  │                   │                                 │   │
│                  │                   ▼                                 │   │
│                  │            Data Store (PostgreSQL)                  │   │
│                  └─────────────────────────────────────────────────────┘   │
│                                     │                                       │
│                                     ▼                                       │
│                         Dashboard Operacional                               │
└─────────────────────────────────────────────────────────────────────────────┘
              │                                     │
              ▼                                     ▼
     Redes Adquirentes                      SPB / BACEN / PIX
     (VISA, Mastercard, ELO)              (Sistema de Pagamentos Brasileiro)
```

---

## 2. Escopo e Objetivos

### 2.1 Objetivos de Negócio

| # | Objetivo |
|---|---|
| O1 | Processar operações financeiras com alta confiabilidade e rastreabilidade completa |
| O2 | Garantir conformidade contínua com as normas do BACEN e do SPB |
| O3 | Oferecer canal seguro de comunicação interbancária via VAN Febraban |
| O4 | Permitir integração de parceiros via API REST ou troca de arquivos (CNAB/PIX) |
| O5 | Fornecer visibilidade operacional em tempo real via dashboard |
| O6 | Suportar o ciclo de liquidação financeira D+n para todos os instrumentos |

### 2.2 Fora do Escopo

- Emissão de cartões ou gestão de contas bancárias próprias
- Processamento de pagamentos internacionais (cross-border)
- Motor antifraude proprietário (integração como serviço externo)
- Interface de usuário final (app do consumidor pagador)

---

## 3. Stakeholders

| Papel | Interesse Principal |
|---|---|
| **Parceiro Comercial** | Integração estável, documentação clara de API, SLA de disponibilidade |
| **Operador de Plataforma** | Visibilidade operacional, alertas de falha, controle de arquivos |
| **Compliance / Risco** | Rastreabilidade completa, retenção de auditoria, conformidade BACEN |
| **Time de Engenharia** | Extensibilidade de layouts, observabilidade, deploys sem impacto |
| **BACEN / SPB** | Aderência às normas, identificação E2E do PIX, relatórios de liquidação |

---

## 4. Restrições e Conformidade

### 4.1 Regulatórias

| Norma | Requisito |
|---|---|
| **BACEN / SPB** | Conformidade com mensageria e identificação de transações PIX (end-to-end ID) |
| **FEBRABAN CNAB 240** | Suporte ao layout padrão para remessa e retorno de arquivos de cobrança/pagamento |
| **FEBRABAN CNAB 400** | Suporte ao layout legado amplamente adotado por bancos tradicionais |
| **Resolução BACEN 4.658** | Requisitos de segurança cibernética para instituições financeiras |

### 4.2 Segurança

| Padrão | Aplicação |
|---|---|
| **PCI-DSS** | Nunca armazenar PAN em claro; dados de cartão somente via token |
| **TLS 1.2+** | Toda comunicação em trânsito criptografada |
| **SHA-256** | Hash de integridade em todos os arquivos financeiros recebidos |
| **LGPD** | Minimização de dados, anonimização de dados sensíveis do titular |

### 4.3 Técnicas

- Banco de dados relacional com suporte a `JSONB`, colunas geradas e UUIDs (PostgreSQL)
- Precisão monetária em `DECIMAL(18,2)` — sem uso de `FLOAT` ou `DOUBLE`
- Chaves de negócio rastreáveis (NSU, end-to-end PIX, nosso número boleto)

---

## 5. Visão Arquitetural

### 5.1 Estilo Arquitetural

A solução adota um estilo **híbrido** combinando:

- **Orientação a eventos** para auditoria e rastreabilidade do ciclo de vida das transações (`transacao_evento` como event log imutável)
- **Pipeline de processamento em lotes** para ingestão de arquivos financeiros (bulk files)
- **API-first** para integração em tempo real com parceiros
- **Modelo estrela (star schema)** na camada de dados para suportar análises OLAP e dashboards

### 5.2 Camadas da Arquitetura

```
┌─────────────────────────────────────────────────────┐
│              CAMADA DE ENTRADA                      │
│   API REST  │  VAN (SFTP/MQ)  │  Dashboard Web      │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│             CAMADA DE PROCESSAMENTO                 │
│                                                     │
│   ┌──────────────────────────────────────────────┐  │
│   │   Hiker — Validação e Travessia de Arquivos  │  │
│   │   configServerFiles — Regras por Layout      │  │
│   │   Bulk Files Pipeline — Carga em Lote        │  │
│   └──────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│               CAMADA DE DADOS                       │
│                                                     │
│   Fato Transação  │  Dimensões  │  Tabelas          │
│   (fato_transacao)│  (dim_*)    │  Operacionais     │
│                   │             │  (arquivo, hiker, │
│                   │             │   liquidação...)  │
└─────────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│            CAMADA DE INTEGRAÇÃO EXTERNA             │
│   Redes Adquirentes  │  SPB/BACEN  │  Motor Antifraude│
└─────────────────────────────────────────────────────┘
```

### 5.3 Princípios Arquiteturais

| Princípio | Descrição |
|---|---|
| **Imutabilidade de auditoria** | Eventos de status e passos do Hiker nunca são deletados ou atualizados |
| **Separação de responsabilidades** | Validação (Hiker) separada de persistência (bulk files) |
| **Configuração externalizada** | Regras de layout por parceiro centralizadas em `configServerFiles` |
| **Tokenização** | Dados de cartão sempre armazenados como token — nunca PAN em claro |
| **Rastreabilidade ponta a ponta** | Toda transação possui chave de negócio rastreável (NSU, E2E, nosso número) |

---

## 6. Componentes Principais

### 6.1 Hiker — Componente de Travessia com Contexto Acumulado

O **Hiker** é o componente central de validação do gateway. Ele é responsável por percorrer o ciclo de vida completo de um arquivo financeiro recebido — desde a chegada até a autorização de carga — **acumulando estado de auditoria** a cada passo, sem modificar a estrutura dos dados originais.

#### Responsabilidades

| Responsabilidade | Detalhe |
|---|---|
| **Recepção e Classificação** | Identificar o tipo de arquivo (remessa, retorno, extrato, posição) e o layout (CNAB 240, CNAB 400, XML BACEN, JSON PIX) |
| **Validação Estrutural** | Verificar integridade de campos obrigatórios, tamanhos, tipos e regras por segmento (header/trailer) |
| **Validação Financeira** | Checar consistência de valores, datas de vencimento, dados do pagador/beneficiário e conformidade BACEN |
| **Acumulação de Contexto** | Manter estado completo da jornada (erros, avisos, totalizadores) entre cada passo |
| **Decisão de Carga** | Ao final da travessia, emitir veredicto: `aprovado`, `rejeitado` ou `pendente_revisao` |
| **Emissão de Eventos** | Publicar eventos de auditoria a cada etapa para o dashboard operacional |

#### Fluxo de Travessia

```
[Arquivo Recebido (VAN / API)]
        │
        ▼
[Passo 1 — Identificação e Classificação]
        │  contexto: { tipo, parceiro, layout, timestamp }
        ▼
[Passo 2 — Validação Estrutural (header/trailer/segmentos)]
        │  contexto: + { registros_lidos, erros_estruturais[] }
        ▼
[Passo 3 — Validação Financeira e Compliance BACEN]
        │  contexto: + { erros_financeiros[], avisos[], totalizadores }
        ▼
[Passo 4 — Decisão de Carga]
        │  contexto: + { status: "aprovado" | "rejeitado" | "pendente" }
        ▼
[configServerFiles → bulk files → pipeline de processamento]
        │
        ▼
[Evento de auditoria → Dashboard operacional]
```

#### Contrato de Interface

```typescript
interface HikerContext {
  arquivoId: string;
  parceiro: string;
  layout: "CNAB240" | "CNAB400" | "XML_BACEN" | "JSON_PIX";
  timestamp: Date;
  registrosLidos: number;
  erros: HikerError[];
  avisos: string[];
  totalizadores: {
    quantidadeRegistros: number;
    valorTotal: number;
  };
  status: "em_travessia" | "aprovado" | "rejeitado" | "pendente_revisao";
}

interface HikerError {
  linha: number;
  campo: string;
  mensagem: string;
  critico: boolean;  // erro crítico impede a carga
}

interface Hiker {
  iniciar(arquivo: ArquivoFinanceiro): HikerContext;
  passo(segmento: Segmento, contexto: HikerContext): HikerContext;
  finalizar(contexto: HikerContext): ResultadoCarga;
}
```

#### Regras de Decisão de Carga

| Condição | Resultado |
|---|---|
| Nenhum erro crítico | `aprovado` → bulk files |
| Um ou mais erros críticos | `rejeitado` → arquivo descartado, parceiro notificado |
| Apenas avisos (sem erros críticos) | `pendente_revisao` → fila de revisão manual |

---

### 6.2 configServerFiles — Servidor de Configuração de Layouts

Centraliza as **regras de validação por parceiro e por layout**. O Hiker consulta este componente no início de cada travessia para obter o schema de validação aplicável.

#### Responsabilidades

- Armazenar e versionar regras de layout por parceiro (`config_layout_arquivo`)
- Suportar regras globais (aplicáveis a todos os parceiros) e regras específicas por parceiro
- Garantir versionamento com período de vigência (`vigente_desde` / `vigente_ate`)
- Expor interface de consulta eficiente para o Hiker

#### Estrutura de Configuração (regras_json)

```json
{
  "header": {
    "tamanho_registro": 240,
    "campos": [
      { "nome": "tipo_registro", "posicao": [1, 1], "tipo": "N", "obrigatorio": true },
      { "nome": "codigo_banco", "posicao": [2, 4], "tipo": "N", "obrigatorio": true }
    ]
  },
  "segmentos": ["A", "B", "J", "O", "W"],
  "validacoes_financeiras": [
    { "regra": "valor_minimo", "valor": 0.01 },
    { "regra": "data_vencimento_futura", "tolerancia_dias": 0 }
  ]
}
```

---

### 6.3 Bulk Files Pipeline — Pipeline de Carga em Lote

Componente responsável por receber os registros **aprovados pelo Hiker** e processá-los em lote no pipeline de transações.

#### Responsabilidades

- Receber o resultado da travessia do Hiker (`aprovado`)
- Inserir registros na tabela `fato_transacao` com status inicial `AGUARDANDO_CARGA`
- Avançar o status para `EM_PROCESSAMENTO` e posteriormente para `ENVIADA_ADQUIRENTE`
- Agrupar transações para liquidação (`liquidacao_financeira`)
- Garantir idempotência — evitar cargas duplicadas com base no hash SHA-256 do arquivo

---

### 6.4 API Layer — Camada de API REST

Interface de integração em tempo real com parceiros para:

- Submissão de transações individuais (cartão presente, PIX, boleto avulso)
- Consulta de status de transação por NSU ou `end_to_end_id`
- Recebimento de webhooks de retorno das redes adquirentes
- Operações de estorno

#### Endpoints Principais

| Método | Recurso | Descrição |
|---|---|---|
| `POST` | `/v1/transacoes` | Submeter nova transação |
| `GET` | `/v1/transacoes/{nsu}` | Consultar transação por NSU |
| `GET` | `/v1/transacoes/{end_to_end_id}/pix` | Consultar transação PIX |
| `POST` | `/v1/transacoes/{id}/estorno` | Solicitar estorno |
| `GET` | `/v1/arquivos/{arquivo_id}/status` | Status de processamento Hiker |
| `POST` | `/v1/webhooks/adquirente` | Receber retorno da rede adquirente |

---

### 6.5 Dashboard Operacional

Interface web de visibilidade operacional que consome os eventos emitidos pelo Hiker e o estado das transações para oferecer:

- Monitoramento em tempo real do pipeline de arquivos
- Consulta e filtragem de transações por status, parceiro, período
- Alertas de arquivos rejeitados ou com erros críticos
- Relatórios de liquidação e conciliação
- Fila de revisão manual para transações `pendente_revisao`

---

## 7. Modelo de Dados

### 7.1 Visão Geral do Esquema

O modelo adota a estrutura de **star schema** para o núcleo analítico, combinada com tabelas operacionais para o ciclo de processamento.

```
                    ┌──────────────────┐
                    │  dim_tempo       │
                    └────────┬─────────┘
                             │
┌──────────────┐   ┌─────────▼──────────────────────────────────────────────┐
│ dim_parceiro │   │                  fato_transacao                        │
│              ├───►  (chave central: transacao_id UUID)                    │
└──────────────┘   │  NSU · end_to_end_id · nosso_numero                   │
                   │  valor_bruto · valor_liquido (gerado)                  │
┌──────────────┐   │  token_cartao · bin_cartao · final_cartao              │
│ dim_meio_    ├───►  score_antifraude · retido_compliance                  │
│ pagamento    │   │  conciliada · data_conciliacao                         │
└──────────────┘   └───────────┬────────────────────┬───────────────────────┘
                               │                    │
┌──────────────┐               │                    │
│ dim_status_  ├───────────────┘    ┌───────────────▼──────┐
│ transacao    │                    │  arquivo_financeiro  │
└──────────────┘                    │  (origem batch)      │
                                    └──────────┬───────────┘
┌──────────────┐                              │
│ dim_canal_   ├───────────────┐   ┌──────────▼───────────┐
│ origem       │               │   │  hiker_auditoria     │
└──────────────┘               │   │  (log por passo)     │
                               │   └──────────────────────┘
                    ┌──────────▼──────────┐
                    │  transacao_evento   │
                    │  (event sourcing)   │
                    └─────────────────────┘
```

### 7.2 Tabelas Dimensão

| Tabela | Propósito |
|---|---|
| `dim_parceiro` | Bancos, fintechs, varejistas e subadquirentes participantes. Inclui ISPB e canal de conectividade |
| `dim_meio_pagamento` | Catálogo dos instrumentos: crédito, débito, boleto, PIX, TED, DOC. Inclui prazo de liquidação D+n |
| `dim_status_transacao` | Ciclo de vida da transação com 12 estados pré-definidos e flag de estado terminal |
| `dim_canal_origem` | Canal de entrada: API REST, VAN Febraban, SFTP, Dashboard |
| `dim_tempo` | Calendário OLAP com dia útil e feriado nacional para análises temporais |

### 7.3 Fato Central — fato_transacao

Granularidade: **uma linha por operação financeira**. Suporta todos os instrumentos de pagamento em uma única tabela com campos específicos por modalidade:

| Grupo de Campos | Descrição |
|---|---|
| **Identificadores de negócio** | `nsu`, `codigo_autorizacao`, `end_to_end_id` (PIX), `nosso_numero` (boleto) |
| **Valores financeiros** | `valor_bruto`, `valor_taxa_gateway`, `valor_taxa_rede`, `valor_liquido` (coluna gerada), `valor_estorno` |
| **Parcelamento** | `numero_parcelas`, `numero_parcela_atual`, `valor_parcela` (cartão crédito) |
| **Cartão tokenizado** | `token_cartao`, `bin_cartao`, `final_cartao`, `bandeira_cartao` — **nunca PAN em claro** |
| **Datas operacionais** | Transação, autorização, vencimento boleto, liquidação, estorno |
| **Compliance** | `ip_origem`, `device_fingerprint`, `score_antifraude` (0–1000), `retido_compliance` |
| **Conciliação** | `conciliada`, `data_conciliacao`, `lote_conciliacao` |

### 7.4 Tabelas Operacionais

| Tabela | Propósito |
|---|---|
| `arquivo_financeiro` | Controla o ciclo de vida de cada arquivo recebido via VAN/SFTP, incluindo hash SHA-256 |
| `hiker_auditoria` | Log imutável dos 4 passos de travessia do Hiker, com `detalhe_json` acumulado |
| `conta_participante` | Contas bancárias e chaves PIX de pagadores e beneficiários |
| `config_layout_arquivo` | Regras de validação versionadas por parceiro e layout (insumo do `configServerFiles`) |

### 7.5 Tabelas de Suporte

| Tabela | Propósito |
|---|---|
| `transacao_evento` | Event log imutável de mudanças de status — rastreabilidade completa (event sourcing lite) |
| `transacao_estorno` | Detalhe de estornos parciais ou totais vinculados à transação original |
| `liquidacao_financeira` | Agrupamento D+n de transações para liquidação interbancária via SPB |
| `liquidacao_transacao` | Associação N:N entre liquidações e transações |

### 7.6 Ciclo de Status da Transação

```
RECEBIDA
    │
    ▼
EM_VALIDACAO ──► VALIDACAO_ERRO (terminal)
    │
    ├──► PENDENTE_REVISAO (revisão manual)
    │
    ▼
AGUARDANDO_CARGA
    │
    ▼
EM_PROCESSAMENTO
    │
    ▼
ENVIADA_ADQUIRENTE
    │
    ├──► NEGADA (terminal)
    │
    ▼
AUTORIZADA
    │
    ├──► CANCELADA (terminal)
    ├──► ESTORNADA (terminal)
    │
    ▼
LIQUIDADA (terminal)
```

---

## 8. Fluxos de Negócio

### 8.1 Fluxo: Processamento de Arquivo Financeiro (Batch)

```
Parceiro                  VAN / SFTP            Hiker               Bulk Files          DB
   │                          │                    │                     │               │
   │── envia arquivo ────────►│                    │                     │               │
   │                          │── notifica ────────►│                    │               │
   │                          │                    │── consulta layout ──►               │
   │                          │                    │◄─ regras JSON ──────►               │
   │                          │                    │                     │               │
   │                          │                    │── passo 1: classif. │               │
   │                          │                    │── passo 2: estrut.  │               │
   │                          │                    │── passo 3: financ.  │               │
   │                          │                    │── passo 4: decisão  │               │
   │                          │                    │                     │               │
   │                          │                    │── [aprovado] ──────►│               │
   │                          │                    │                     │── INSERT ────►│
   │                          │                    │                     │               │
   │                          │◄── evento auditoria─│                    │               │
   │◄── notificação retorno ──│                    │                     │               │
```

### 8.2 Fluxo: Transação PIX (API em Tempo Real)

```
Parceiro              API Layer           fato_transacao      SPB / BACEN
   │                      │                     │                   │
   │── POST /transacoes ──►│                     │                   │
   │   (JSON PIX)          │── valida e insere ──►│                   │
   │                       │   status: RECEBIDA   │                   │
   │                       │── envia ao SPB ──────────────────────────►│
   │                       │                     │                   │
   │                       │◄──── retorno SPB ────────────────────────│
   │                       │── atualiza status ──►│                   │
   │                       │   AUTORIZADA / NEGADA│                   │
   │◄── resposta API ──────│                     │                   │
   │   + transacao_evento   │                     │                   │
```

### 8.3 Fluxo: Liquidação Financeira D+n

```
Scheduler           liquidacao_financeira     fato_transacao      SPB
    │                        │                       │               │
    │── acionar D+n ─────────►│                       │               │
    │                        │── seleciona LIQUIDADA─►│               │
    │                        │◄── transações ─────────│               │
    │                        │── gera lote ───────────────────────────►│
    │                        │◄── confirmação ────────────────────────│
    │                        │── status: LIQUIDADO    │               │
    │                        │── atualiza conciliada──►│               │
```

### 8.4 Fluxo: Estorno

```
Parceiro            API Layer           transacao_estorno    fato_transacao   Rede
   │                    │                       │                  │             │
   │── POST /estorno ───►│                       │                  │             │
   │                    │── valida original ─────────────────────►│             │
   │                    │── INSERT estorno ──────►│                 │             │
   │                    │── status: SOLICITADO    │                 │             │
   │                    │── envia à rede ──────────────────────────────────────►│
   │                    │◄── confirmação ──────────────────────────────────────│
   │                    │── status: CONFIRMADO ───►│                │             │
   │                    │── status transação: ESTORNADA ──────────►│             │
   │◄── resposta ───────│                         │                │             │
```

---

## 9. Integrações Externas

| Sistema Externo | Protocolo | Direção | Descrição |
|---|---|---|---|
| **VAN Febraban** | SFTP / MQ | Bidirecional | Troca de arquivos CNAB com bancos parceiros |
| **Redes Adquirentes** (VISA, Mastercard, ELO) | ISO 8583 / API | Bidirecional | Autorização e liquidação de cartões |
| **SPB / BACEN** | API BACEN / ISO 20022 | Bidirecional | Processamento PIX, TED, DOC e liquidação |
| **Motor Antifraude** | API REST | ← Consulta | Score de risco 0–1000 por transação |
| **Parceiros Comerciais** | API REST / SFTP | Bidirecional | Submissão de transações e recebimento de retornos |
| **Dashboard** | WebSocket / REST | ← Eventos | Consumo de eventos de auditoria do Hiker |

### 9.1 Conectividade com Parceiros

| Canal | Uso |
|---|---|
| **API REST** | Transações em tempo real, consultas, estornos, webhooks |
| **VAN (SFTP/MQ)** | Remessas e retornos de arquivos CNAB, boleto registrado |
| **SFTP direto** | Troca de arquivos com parceiros sem VAN |

---

## 10. Segurança e Compliance

### 10.1 Proteção de Dados de Cartão (PCI-DSS)

- **Nunca armazenar PAN em claro**: campo `token_cartao` substitui o número completo
- `bin_cartao` (6 primeiros dígitos) e `final_cartao` (4 últimos) permitidos para exibição
- Tokenização realizada pelo gateway ou pela rede adquirente antes da persistência
- Chave de encryption gerenciada por HSM (Hardware Security Module) externo

### 10.2 Integridade de Arquivos

- Hash **SHA-256** calculado no recebimento e armazenado em `arquivo_financeiro.hash_sha256`
- Verificação de idempotência no bulk files pipeline: arquivos com hash duplicado são rejeitados
- Registro imutável de cada passo do Hiker em `hiker_auditoria`

### 10.3 Rastreabilidade e Auditoria

- **Event sourcing lite**: toda mudança de status gera registro em `transacao_evento` (nunca deletado)
- Log de auditoria do Hiker com `detalhe_json` contendo o contexto acumulado a cada passo
- Retenção de `ip_origem` e `device_fingerprint` para investigações de fraude

### 10.4 Controle de Acesso

- Parceiros autenticados por certificado mTLS e API Key no canal API
- Acesso ao Dashboard com autenticação multifator (MFA)
- Segregação de funções: operador não tem acesso direto ao banco de dados
- Auditoria de acessos ao dashboard em tabela separada de logs

### 10.5 Compliance BACEN

- `end_to_end_id` do PIX conforme padrão BACEN: `E + ISPB(8) + AAAAMMDD + T + sequencial`
- `score_antifraude` com limiar de risco configurável (padrão: >= 700 = alto risco, reter para revisão)
- Campo `retido_compliance` para transações retidas aguardando revisão manual
- Relatórios de liquidação D+n gerados em `liquidacao_financeira` para prestação de contas ao SPB

---

## 11. Atributos de Qualidade

### 11.1 Disponibilidade

| Requisito | Meta |
|---|---|
| Disponibilidade do gateway | ≥ 99,9% (< 8,7h/ano de indisponibilidade) |
| Canal PIX (exigência BACEN) | 24×7×365 sem janela de manutenção |
| API REST | ≥ 99,5% durante horário comercial |

### 11.2 Desempenho

| Requisito | Meta |
|---|---|
| Latência API (P95) | < 500ms para transações em tempo real |
| Throughput bulk files | ≥ 100.000 registros/arquivo sem degradação |
| Consulta por NSU/E2E | < 100ms com índices (`idx_fato_transacao_nsu`, `idx_fato_transacao_end_to_end`) |

### 11.3 Escalabilidade

- Índices estratégicos em `fato_transacao` para os padrões de acesso mais frequentes
- `dim_tempo` permite particionamento futuro de `fato_transacao` por `tempo_id`
- Componente Hiker stateless por arquivo (contexto encapsulado em `HikerContext`) — horizontalmente escalável

### 11.4 Rastreabilidade

- Toda transação possui ao menos uma chave de negócio rastreável (NSU, E2E, nosso número)
- Histórico completo de status via `transacao_evento` — permite reconstruir o estado em qualquer ponto no tempo
- Auditoria granular por arquivo via `hiker_auditoria` (4 passos com contexto acumulado)

### 11.5 Extensibilidade

- Novos layouts (ex: ISO 20022) adicionados via `config_layout_arquivo` sem deploy de código
- Novos meios de pagamento adicionados em `dim_meio_pagamento` com zero impacto nas transações existentes
- Novos parceiros onboardados via `dim_parceiro` + `config_layout_arquivo`

### 11.6 Observabilidade

- Eventos de auditoria publicados pelo Hiker para o Dashboard em cada passo da travessia
- Status de arquivo em `arquivo_financeiro.status_hiker` consultável em tempo real
- `hiker_auditoria.detalhe_json` armazena contexto acumulado completo para diagnóstico

---

## 12. Decisões Arquiteturais (ADRs)

### ADR-001: Star Schema para Modelo de Dados

**Contexto**: O gateway processa múltiplos instrumentos de pagamento com ciclos de vida distintos e necessita de análises OLAP para o dashboard operacional.

**Decisão**: Adotar star schema com `fato_transacao` no centro e dimensões imutáveis (`dim_*`).

**Consequências**: Consultas analíticas eficientes com joins simples; overhead de join nas consultas operacionais mitigado pelos índices criados.

---

### ADR-002: Event Sourcing Lite para Ciclo de Vida da Transação

**Contexto**: Requisito de rastreabilidade completa e auditoria regulatória exige histórico de todos os estados de cada transação.

**Decisão**: Tabela `transacao_evento` como log imutável de append-only. O estado atual é mantido em `fato_transacao.status_id`; o histórico completo está em `transacao_evento`.

**Consequências**: Rastreabilidade total sem complexidade de event sourcing pleno; estado atual de fácil consulta; histórico disponível para auditoria e compliance.

---

### ADR-003: Hiker como Componente de Travessia Stateful por Arquivo

**Contexto**: Validação de arquivos financeiros CNAB/PIX requer múltiplas passagens com contexto acumulado (erros, totalizadores, avisos) antes de autorizar a carga.

**Decisão**: Implementar o padrão "travessia com contexto acumulado" — cada passo recebe e retorna o `HikerContext` imutável, sem modificar o arquivo original.

**Consequências**: Testabilidade alta (cada passo é uma função pura); paralelismo possível entre arquivos independentes; contexto completo disponível para auditoria via `hiker_auditoria.detalhe_json`.

---

### ADR-004: Configuração de Layout Externalizada (configServerFiles)

**Contexto**: Existem múltiplos layouts (CNAB 240, CNAB 400, XML BACEN, JSON PIX) e variações por parceiro. Regras mudam com alterações normativas do BACEN/Febraban.

**Decisão**: Centralizar todas as regras de validação em `config_layout_arquivo` como JSONB versionado. O Hiker nunca hardcoda regras de layout.

**Consequências**: Atualizações de layout sem redeploy; suporte a regras globais e específicas por parceiro; versionamento com vigência temporal garante compatibilidade retroativa.

---

### ADR-005: Tokenização Obrigatória de Dados de Cartão

**Contexto**: Conformidade PCI-DSS veda o armazenamento de PAN (Primary Account Number) em claro em qualquer base de dados.

**Decisão**: `fato_transacao.token_cartao` é obrigatório para transações de cartão. O token é gerado antes da inserção. PAN nunca trafega pelo banco de dados interno.

**Consequências**: Conformidade PCI-DSS nativa; escopo de auditoria PCI restrito à camada de tokenização (HSM/rede adquirente); perda de funcionalidade de busca por número de cartão (mitigada por `bin_cartao` + `final_cartao`).

---

### ADR-006: UUID como Chave Primária nas Tabelas Transacionais

**Contexto**: Distribuição geográfica futura, geração de IDs sem coordenação central e rastreabilidade externa requerem chaves globalmente únicas.

**Decisão**: `transacao_id`, `arquivo_id`, `conta_id`, `estorno_id` e `liquidacao_id` usam `UUID` com `gen_random_uuid()`.

**Consequências**: Sem colisão em cenários distribuídos; chaves exposíveis externamente sem risco de enumeração; leve overhead de armazenamento vs. `BIGSERIAL` (mitigado pelos índices seletivos com `WHERE`).

---

## 13. Glossário

| Termo | Definição |
|---|---|
| **BACEN** | Banco Central do Brasil — regulador do sistema financeiro nacional |
| **CNAB 240** | Layout padrão Febraban para arquivos de remessa/retorno com registro de 240 bytes |
| **CNAB 400** | Layout legado Febraban com registro de 400 bytes, amplamente usado por bancos tradicionais |
| **SPB** | Sistema de Pagamentos Brasileiro — infraestrutura de liquidação do BACEN |
| **PIX** | Sistema de pagamentos instantâneos do BACEN, disponível 24×7 |
| **VAN** | Value Added Network — rede de valor agregado para troca segura de arquivos interbancários |
| **TED** | Transferência Eletrônica Disponível — liquidação no mesmo dia útil |
| **DOC** | Documento de Ordem de Crédito — liquidação em D+1 (em extinção) |
| **NSU** | Número Sequencial Único — identificador de transação gerado pelo gateway |
| **E2E ID** | Identificador ponta a ponta do PIX (`E+ISPB+AAAAMMDD+T+sequencial`) |
| **ISPB** | Identificador do Sistema de Pagamentos Brasileiro — código de 8 dígitos do BACEN |
| **PAN** | Primary Account Number — número completo do cartão (nunca armazenado em claro) |
| **PCI-DSS** | Payment Card Industry Data Security Standard — norma de segurança para dados de cartão |
| **HSM** | Hardware Security Module — equipamento para gestão segura de chaves criptográficas |
| **Hiker** | Componente de travessia com contexto acumulado do gateway — valida arquivos financeiros passo a passo |
| **configServerFiles** | Componente que centraliza e versiona as regras de layout e validação por parceiro |
| **Bulk Files** | Pipeline de carga em lote de registros aprovados pelo Hiker |
| **D+n** | Prazo de liquidação financeira: D+0 = mesmo dia, D+1 = próximo dia útil, etc. |
| **Star Schema** | Modelo dimensional com tabela fato central e dimensões ao redor, otimizado para OLAP |
| **Event Sourcing** | Padrão arquitetural onde o estado é derivado de uma sequência imutável de eventos |
| **LGPD** | Lei Geral de Proteção de Dados — lei brasileira de proteção de dados pessoais |
| **mTLS** | Mutual TLS — autenticação bidirecional por certificado entre cliente e servidor |
| **Score Antifraude** | Pontuação 0–1000 de risco por transação; score ≥ 700 indica alto risco |
