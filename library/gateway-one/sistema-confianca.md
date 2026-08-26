# Documento de Arquitetura de Software
## Sistema Confiança — Validação e Conciliação de Arquivos de Cobrança em Alto Volume

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Proposta para validação |
| Domínio | Cobrança, conciliação bancária e recuperação financeira |
| Papel | Produto complementar e paralelo ao Gateway de Pagamentos |
| Público | Bancos, fintechs, varejistas, credores, servicers e operadores financeiros |
| Referências | `gateway-pagamentos-arquitetura-software.md` · `gateway-pagamentos.sql` |
| Proposta de valor | Transformar divergências de arquivos em confiança, evidência e ação financeira |

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Problema e Oportunidade](#2-problema-e-oportunidade)
3. [Proposta de Produto](#3-proposta-de-produto)
4. [Escopo e Objetivos](#4-escopo-e-objetivos)
5. [Personas e Casos de Uso](#5-personas-e-casos-de-uso)
6. [Visão Arquitetural](#6-visão-arquitetural)
7. [Componentes Principais](#7-componentes-principais)
8. [Modelo de Domínio e Dados](#8-modelo-de-domínio-e-dados)
9. [Motor de Validação e Matching](#9-motor-de-validação-e-matching)
10. [Processamento de Alto Volume](#10-processamento-de-alto-volume)
11. [BI e Experiência do Produto](#11-bi-e-experiência-do-produto)
12. [Fluxos de Negócio](#12-fluxos-de-negócio)
13. [Segurança, Governança e Auditoria](#13-segurança-governança-e-auditoria)
14. [Atributos de Qualidade](#14-atributos-de-qualidade)
15. [Integrações e Contratos](#15-integrações-e-contratos)
16. [Roadmap e Empacotamento Comercial](#16-roadmap-e-empacotamento-comercial)
17. [Decisões Arquiteturais (ADRs)](#17-decisões-arquiteturais-adrs)
18. [Roteiro de Demonstração Comercial](#18-roteiro-de-demonstração-comercial)
19. [Premissas e Próximas Decisões](#19-premissas-e-próximas-decisões)
20. [Glossário](#20-glossário)

---

## 1. Visão Geral

O **Sistema Confiança** é uma plataforma de validação, comparação e conciliação de arquivos de cobrança individual em alto volume. A solução compara a cobrança esperada pelo negócio com os registros recebidos de bancos, adquirentes, processadores, bureaus ou parceiros.

O produto trata especialmente inconsistências entre a chave do contrato, a identificação do cliente, o número da parcela, os valores, as datas, o nosso número, o status e a origem do registro. Seu objetivo é evitar que uma divergência aparentemente pequena gere falha na conciliação bancária, baixa incorreta, retrabalho ou perda financeira.

A plataforma opera em paralelo ao Gateway de Pagamentos e aos sistemas de cobrança. Ela não substitui o banco, o ERP ou o core financeiro. Cria uma camada independente de confiança capaz de:

- validar registros antes do envio ao banco;
- comparar remessa, retorno e extrato;
- explicar a causa de cada divergência;
- impedir baixa incorreta ou encaminhar o item para revisão;
- preservar evidências e versões das regras;
- medir o impacto financeiro e operacional da qualidade dos arquivos.

### 1.1 Perguntas respondidas por cobrança

1. Qual contrato e cliente este registro representa?
2. A parcela correta foi identificada?
3. O valor recebido corresponde ao esperado, considerando juros, multa, desconto e tarifa?
4. O pagamento foi liquidado no lote e na conta esperados?
5. Se houve divergência, qual é a causa, o impacto e a ação recomendada?
6. Quais ocorrências representam maior risco de perda financeira?

### 1.2 Princípios de confiança

| Princípio | Aplicação |
|---|---|
| Confiança antes de volume | Nenhum registro é conciliado sem evidência suficiente |
| Explicabilidade | Toda decisão mostra fontes, regras e campos comparados |
| Idempotência | Reprocessar não duplica cobrança, pagamento ou divergência |
| Evidência preservada | Original, normalização, regra e decisão são rastreáveis |
| Ação por impacto | Prioridade considera valor, prazo, recorrência e risco |
| Independência | A plataforma não altera diretamente a origem financeira |
| Escala horizontal | Filas, partições e workers absorvem o volume |
| Dado honesto | Conciliado, atrasado, não localizado e ambíguo são estados diferentes |

### 1.3 Contexto da solução

```text
┌──────────────────────────────────┐
│ Fontes do cliente                │
│ Contratos · parcelas · clientes  │
│ Cobrança emitida · pagamentos    │
└───────────────┬──────────────────┘
                │ arquivos / API / CDC
                ▼
┌────────────────────────────────────────────────────────────┐
│                    SISTEMA CONFIANÇA                       │
│                                                            │
│ Ingestão · Normalização · Matching · Validação             │
│ Conciliação · Divergências · Evidências · BI · Alertas    │
└───────────────┬────────────────────────────────────────────┘
                │ leitura e resultados
                ▼
┌──────────────────────────────────┐
│ Bancos, VAN, SFTP e Gateway      │
│ CNAB · APIs · retornos · extrato │
└──────────────────────────────────┘
```

---

## 2. Problema e Oportunidade

### 2.1 Problema de negócio

Em operações com milhões de registros, a conciliação costuma depender de chaves incompletas, layouts diferentes e regras implícitas. Uma pequena divergência de posição, formatação, parcela ou atualização monetária pode fazer com que um pagamento real seja classificado como não localizado ou atribuído à parcela errada.

Os efeitos incluem pagamentos não conciliados, baixa incorreta ou atrasada, cobrança indevida, repasse no contrato errado, diferenças financeiras sem causa, horas de análise manual e perda de prazo para recuperação.

### 2.2 Causas recorrentes

| Categoria | Exemplos |
|---|---|
| Identificação | Máscara, dígito divergente, truncamento ou contrato duplicado |
| Cliente | Documento incompatível, cadastro desatualizado ou titular ambíguo |
| Parcela | Ausência, deslocamento, repetição, renegociação ou parcela já quitada |
| Valor | Juros, multa, desconto, tarifa, arredondamento ou bruto versus líquido |
| Data | Dia útil, vencimento alterado, pagamento e crédito em datas diferentes |
| Layout | CNAB 240/400, encoding, posição, versão ou coluna divergente |
| Origem | Arquivo duplicado, lote incompleto ou retorno parcial |
| Integração | Atraso, evento fora de ordem ou reprocessamento sem idempotência |

### 2.3 Oportunidade comercial

O Sistema Confiança posiciona a empresa além do processamento de arquivos: oferece **controle financeiro, prevenção de perdas e produtividade operacional**.

O valor deve ser demonstrado por três indicadores:

- percentual de registros conciliados automaticamente;
- valor recuperado ou protegido;
- tempo médio para explicar e resolver uma divergência.

O produto deve separar valor efetivamente recuperado, valor bloqueado preventivamente e estimativa operacional. Estimativa não deve ser apresentada como receita realizada.

---

## 3. Proposta de Produto

### 3.1 Posicionamento

**Sistema Confiança** é uma **Confidence Platform para Cobrança e Recebíveis**. Combina processamento de alto volume, regras configuráveis, reconciliação explicável e Business Intelligence para que o cliente veja a operação e aja sobre as exceções.

### 3.2 Módulos

| Módulo | Valor entregue |
|---|---|
| Confidence Ingest | Recebimento, integridade, hash e identificação de arquivos |
| Confidence Match | Associação de registros entre fontes usando chaves graduais |
| Confidence Rules | Validação de contrato, cliente, parcela, valor e datas |
| Confidence Reconcile | Decisão de conciliação e evidências |
| Confidence Exceptions | Fila de divergências por causa, severidade e impacto |
| Confidence BI | Indicadores de qualidade, risco, aging e recuperação |
| Confidence Recover | Priorização de ações de recuperação financeira |
| Confidence API | Consulta e integração com ERP, atendimento e BI do cliente |

### 3.3 Estados do registro

```text
RECEBIDO → NORMALIZADO → IDENTIFICADO → VALIDADO → CONCILIADO → ENCERRADO
                         │             │           │
                         ├─ NÃO_IDENTIFICADO
                         ├─ DIVERGENTE
                         └─ PENDENTE_REVISAO
```

Estados técnicos auxiliares incluem `AGUARDANDO_FONTE`, `EM_PROCESSAMENTO`, `DUPLICADO`, `BLOQUEADO_QUALIDADE`, `REABERTO` e `CANCELADO`.

---

## 4. Escopo e Objetivos

### 4.1 Objetivos

| # | Objetivo |
|---|---|
| O1 | Validar arquivos individuais em escala de milhões de registros |
| O2 | Aumentar a conciliação automática com regras explicáveis |
| O3 | Reduzir perdas causadas por contrato, cliente, parcela ou valor divergentes |
| O4 | Reduzir esforço manual de investigação e atendimento |
| O5 | Oferecer trilha de auditoria sobre cada decisão e fonte |
| O6 | Criar produto demonstrável e empacotável pelo time de vendas |
| O7 | Integrar-se ao Gateway e aos sistemas do cliente sem assumir o controle transacional |

### 4.2 Escopo inicial

- Ingestão via API, SFTP, VAN ou upload controlado.
- CNAB 240, CNAB 400, CSV, TXT e formatos configuráveis.
- Normalização sem perda dos valores originais.
- Matching de contrato, cliente, parcela e cobrança.
- Validação de valor, vencimento, pagamento, tarifa, juros e desconto.
- Reconciliação de remessa, retorno, extrato e liquidação.
- Classificação de divergências e cálculo de impacto financeiro.
- Reprocessamento idempotente e fechamento de totalizadores.
- Dashboard executivo, financeiro e operacional.
- Alertas, fila de exceções e exportação controlada.
- API de consulta e integração com BI do cliente.

### 4.3 Fora do escopo inicial

- Emissão de boletos ou cobrança como sistema principal.
- Alteração direta de contratos, clientes ou parcelas na origem.
- Baixa automática irreversível sem política aprovada.
- Motor de crédito ou antifraude completo.
- Correção silenciosa do arquivo.
- Armazenamento de PAN em claro.
- Substituição do ERP, core bancário ou sistema contábil.

---

## 5. Personas e Casos de Uso

| Persona | Pergunta | Funcionalidade |
|---|---|---|
| CFO / diretor financeiro | Quanto dinheiro está em risco? | Valor conciliado, divergente, pendente e recuperável |
| Gestor de cobrança | Onde a cobrança está falhando? | Funil por carteira, banco, lote, contrato e causa |
| Analista de conciliação | Qual é a causa desta diferença? | Comparação campo a campo e evidências |
| Operador de arquivos | O arquivo chegou completo e correto? | Integridade, layout, volume, hash e progresso |
| Atendimento | Por que o cliente ainda aparece em aberto? | Busca, parcela e linha do tempo |
| Auditor / compliance | A decisão pode ser comprovada? | Evidência, regra, origem e histórico |
| Tecnologia / dados | Posso consumir os resultados? | APIs, eventos, views e exportação |
| Vendas / pré-vendas | Como demonstrar valor? | Tenant demo e cenários de divergência |

### 5.1 Casos prioritários

1. Validar arquivo antes de sua utilização ou transmissão.
2. Conferir retorno bancário contra a cobrança emitida.
3. Identificar pagamento sem correspondência exata.
4. Detectar valor fora da tolerância configurada.
5. Encontrar pagamento associado à parcela incorreta.
6. Detectar contrato, cliente ou parcela duplicados.
7. Explicar diferenças entre lote bancário, extrato e contabilização.
8. Priorizar recuperação financeira.
9. Medir qualidade por banco, parceiro, layout e canal.

---

## 6. Visão Arquitetural

### 6.1 Estilo

A solução adota uma arquitetura **event-driven, batch-native e analytics-first**, separando ingestão, processamento, decisão e consulta. Arquivos originais são preservados; registros são processados em partições; decisões são persistidas com evidências; dados analíticos ficam isolados das consultas transacionais do cliente.

### 6.2 Arquitetura lógica

```text
┌───────────────────────────────────────────────────────────────┐
│ Experiência: Portal · BI embedded · API · Relatórios         │
└──────────────────────────────┬────────────────────────────────┘
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Produto: tenant/RBAC · BFF · busca · exceções · alertas       │
└──────────────────────────────┬────────────────────────────────┘
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Decisão: regras · matching · tolerância · score · evidência   │
└──────────────────────────────┬────────────────────────────────┘
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Processamento: filas · workers · checkpoints · DLQ            │
└──────────────────────────────┬────────────────────────────────┘
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Dados: original · staging · warehouse · data marts            │
└──────────────────────────────┬────────────────────────────────┘
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Fontes: cobrança · contratos · parcelas · bancos · Gateway     │
└───────────────────────────────────────────────────────────────┘
```

### 6.3 Separação de responsabilidades

| Camada | Faz | Não faz |
|---|---|---|
| Ingestão | Recebe, hasheia e registra origem | Decide conciliação |
| Normalização | Padroniza formatos preservando o original | Corrige silenciosamente |
| Matching | Encontra candidatos e evidências | Efetiva baixa |
| Regras | Compara campos e classifica divergências | Esconde exceções |
| Conciliação | Consolida decisão e impacto | Altera a origem |
| BI | Exibe indicadores e padrões | Recalcula regras fora do catálogo |
| Workflow | Controla revisão e resolução | Apaga histórico |

### 6.4 Arquitetura de alto volume

```text
Arquivos / APIs / CDC
          │
          ▼
Object Storage: original imutável
          │
          ▼
Fila de ingestão → Orquestrador → Partições paralelas
                                      │
                          Normalização + Matching + Regras
                                      │
                         Resultados idempotentes
                              │                 │
                              ▼                 ▼
                       Data mart operacional  Warehouse / BI
                              │                 │
                              ▼                 ▼
                       Exceções e alertas   Painéis e relatórios
```

A plataforma deve usar cópias, eventos, snapshots ou APIs de leitura. Não deve executar consultas analíticas diretamente no OLTP do cliente.

---

## 7. Componentes Principais

### 7.1 File Intake Service

Recebe arquivos e mensagens, calcula SHA-256, identifica tenant, origem, layout e período, verifica duplicidade, armazena o original e publica `ArquivoRecebido`.

### 7.2 Layout Registry

Catálogo versionado de posições, tipos, encoding, datas, obrigatoriedade, totalizadores, transformações e vigência por banco, cliente e layout.

### 7.3 Normalization Service

Produz modelo canônico sem apagar a origem. Guarda valor original, valor normalizado, transformação, posição, linha e fonte. Normaliza identificadores, documentos, datas, valores e status.

### 7.4 Reference Data Service

Disponibiliza contratos, clientes, parcelas, títulos, identificadores bancários, regras financeiras, contas e calendário. A referência é versionada por snapshot e data de validade.

### 7.5 Matching Engine

Localiza a cobrança esperada e retorna candidatos, score técnico, conflitos, chaves usadas e evidências. Score não equivale a probabilidade de verdade.

### 7.6 Validation and Reconciliation Engine

Aplica validações estruturais, referenciais, financeiras e de liquidação. Produz decisão, códigos de divergência, impacto, recomendação e versão da regra.

### 7.7 Exception Management

Fila de exceções com atribuição, prioridade, SLA, comentários, anexos, aprovação, reprocessamento, resolução e reabertura.

### 7.8 Reconciliation Ledger

Ledger append-only dos vínculos entre cobrança esperada, registro recebido, retorno, extrato e liquidação. Permite reconstruir cada decisão.

### 7.9 BI and Insight Service

Expõe métricas certificadas, dimensões, tendências, alertas e análises de causa. Portal, BI e exportações consomem a mesma camada semântica.

---

## 8. Modelo de Domínio e Dados

### 8.1 Entidades

| Entidade | Granularidade | Propósito |
|---|---|---|
| `arquivo_origem` | Um arquivo recebido | Hash, origem, layout e ciclo |
| `lote_origem` | Um lote dentro do arquivo | Totalizadores e agrupamento |
| `cobranca_esperada` | Uma cobrança ou parcela | Verdade do contrato |
| `registro_recebido` | Uma linha de retorno ou extrato | Dado observado |
| `candidato_match` | Uma relação possível | Evidência e confiança |
| `validacao_resultado` | Uma regra por registro | Resultado e severidade |
| `conciliacao` | Relação final | Estado financeiro |
| `divergencia` | Uma inconsistência | Causa, impacto e resolução |
| `evidencia` | Uma prova da decisão | Campo, fonte e comparação |
| `regra_validacao` | Uma regra versionada | Fórmula, tolerância e vigência |
| `evento_processamento` | Um evento técnico ou negócio | Auditoria e replay |

### 8.2 Modelo conceitual

```text
cliente ──< contrato ──< parcela ──< cobranca_esperada
                                      │
arquivo_origem ──< lote_origem ──< registro_recebido
                                      │
                                      ▼
                              candidato_match
                                      │
                                      ▼
                              conciliacao
                               │          │
                               ▼          ▼
                         validacao     divergencia
                               │          │
                               └────┬─────┘
                                    ▼
                                evidencia
```

### 8.3 Campos canônicos

- Identificação: `tenant_id`, `cliente_id`, `contrato_id`, `parcela_id`, `titulo_id`, `nosso_numero`, `identificador_origem`.
- Valores: `valor_original`, `valor_atualizado_esperado`, `valor_pago`, `valor_creditado`, `valor_tarifa`, `valor_diferenca`, `moeda`.
- Datas: `data_vencimento`, `data_pagamento`, `data_credito`, `data_liquidacao`.
- Rastreabilidade: `arquivo_id`, `lote_id`, `linha_origem`, `hash_registro`, `regra_version`, `snapshot_id`, `correlation_id`, `processamento_id`.

A plataforma deve distinguir chave técnica, chave de negócio, chave de origem, chave composta, chave de correlação e chave de deduplicação.

### 8.4 Granularidade e idempotência

O resultado mínimo é um registro recebido comparado com uma cobrança esperada, podendo haver múltiplos candidatos. A mesma chave de ingestão não pode gerar duplicidade na mesma execução. Nova regra ou nova referência cria novo resultado relacionado ao anterior, sem sobrescrever o histórico.

---

## 9. Motor de Validação e Matching

### 9.1 Matching progressivo

| Nível | Critério | Decisão sugerida |
|---|---|---|
| M1 | Identificador único exato | Candidato forte, validar demais campos |
| M2 | Contrato + parcela exatos | Validar cliente, valor e datas |
| M3 | Contrato + cliente + parcela | Validar composição financeira |
| M4 | Contrato + vencimento + valor tolerado | Pendente de política |
| M5 | Cliente + parcela + janela de data | Revisão ou score alto |
| M6 | Similaridade parcial | Nunca aprovar automaticamente sem política |

Em empate entre candidatos, o item vai para revisão. A interface deve explicar a evidência, por exemplo: “contrato e cliente conferem; parcela confere; valor diverge em R$ 10,00”.

### 9.2 Validações

**Estrutural**: tamanho, campos, tipos, header, trailer, codificação, quantidade e totalizadores.

**Referencial**: contrato existente e vigente, cliente pertencente, parcela válida, título elegível, nosso número autorizado e snapshot correto.

**Financeira**: valor esperado versus recebido, juros, multa, desconto, tarifa, arredondamento, duplicidade e composição bruto/líquido.

**Reconciliação**: remessa versus aceite, retorno versus remessa, pagamento versus título e liquidação versus contabilização.

### 9.3 Códigos de divergência

| Código | Descrição | Severidade |
|---|---|---|
| `D01` | Contrato não localizado | Alta |
| `D02` | Contrato duplicado ou ambíguo | Crítica |
| `D03` | Cliente divergente | Alta |
| `D04` | Parcela não localizada | Alta |
| `D05` | Parcela já conciliada | Crítica |
| `D06` | Parcela divergente | Média |
| `D07` | Valor acima da tolerância | Alta |
| `D08` | Valor abaixo da tolerância | Alta |
| `D09` | Tarifa ou desconto sem composição | Média |
| `D10` | Vencimento divergente | Média |
| `D11` | Pagamento fora da janela | Média |
| `D12` | Registro duplicado | Crítica |
| `D13` | Lote ou totalizador divergente | Alta |
| `D14` | Fonte esperada não recebida | Crítica |
| `D15` | Layout inválido | Alta |
| `D16` | Pagamento sem cobrança | Crítica |
| `D17` | Cobrança sem retorno | Média |
| `D18` | Liquidação não localizada | Crítica |
| `D19` | Evento fora de sequência | Média |
| `D20` | Dados insuficientes | Média |

### 9.4 Política de decisão

| Condição | Decisão |
|---|---|
| Chaves fortes, valor dentro da tolerância e sem alerta | `APROVADO` |
| Erro estrutural ou chave crítica inválida | `REJEITADO` |
| Candidato único com valor divergente | `PENDENTE_EXCECAO` |
| Mais de um candidato | `PENDENTE_REVISAO` |
| Retorno sem cobrança esperada | `NAO_CONCILIADO` |
| Diferença autorizada por regra | `APROVADO_COM_ALERTA` |
| Arquivo ou registro repetido | `DUPLICADO` |

A automação deve ser conservadora em decisões que possam gerar baixa financeira.

### 9.5 Tolerâncias

Tolerâncias absoluta, percentual, por componente, calendário, banco ou carteira devem ser explícitas e versionadas. Toda diferença deve continuar registrada. Valores monetários usam `DECIMAL`, nunca `FLOAT` ou `DOUBLE`.

---

## 10. Processamento de Alto Volume

### 10.1 Pipeline

1. Persistir o original e seus metadados.
2. Registrar execução e chave de idempotência.
3. Validar header, trailer e layout.
4. Particionar por blocos determinísticos.
5. Processar normalização, matching e regras em workers paralelos.
6. Fazer bulk lookup em snapshots de referência.
7. Persistir resultados em batches.
8. Consolidar duplicidade, sequência, totais e decisão final.
9. Atualizar BI, alertas e relatório.

O arquivo completo não deve ser carregado na memória de um único worker.

### 10.2 Concorrência e proteção

- Filas independentes para ingestão, parsing, matching, validação e reconciliação.
- Limites por tenant, banco, arquivo e sistema de referência.
- Backpressure, retry com backoff, circuit breaker e DLQ.
- Autoscaling por profundidade de fila, idade da mensagem e duração.
- Cache e snapshots de referência para evitar consultas linha a linha.

### 10.3 Idempotência

| Nível | Chave sugerida |
|---|---|
| Arquivo | `tenant_id + hash_sha256 + tipo + período` |
| Partição | `arquivo_id + particao + regra_version` |
| Registro | `arquivo_id + linha + hash_registro` |

Reprocessamento por nova regra cria uma nova execução e mantém a comparação com o resultado anterior.

### 10.4 Metas iniciais de capacidade

| Indicador | Meta para validação |
|---|---|
| Registros por execução | Até 10 milhões |
| Throughput | 5.000 a 20.000 registros/segundo |
| Atualização do dashboard | Até 5 minutos após resultado |
| Retomada | Partição interrompida, sem reiniciar tudo |
| Idempotência | Nenhuma duplicidade financeira |
| Consulta operacional | P95 inferior a 2 segundos |

As metas dependem do layout, quantidade de joins, percentual de divergência e infraestrutura, devendo ser confirmadas por benchmark.

### 10.5 Fechamento

A execução só termina quando partições, totalizadores, duplicidades, resultados, qualidade, versões de regra e alertas estiverem consolidados. Falhas devem permanecer visíveis.

---

## 11. BI e Experiência do Produto

### 11.1 Papel do BI

BI apoia a decisão, mas não substitui o motor de validação. O motor decide registro a registro; o BI mostra impacto, tendência, concentração, aging e prioridade.

### 11.2 Navegação

```text
Visão geral
├── Saúde da conciliação
├── Arquivos e lotes
├── Cobranças e parcelas
├── Divergências e evidências
├── Recuperação financeira
├── Bancos e parceiros
├── Relatórios
└── Administração
```

### 11.3 Painéis

**Executivo**: valor esperado, conciliado, divergente, sem correspondência, potencialmente recuperável, taxa de automação, tempo de resolução e concentração por origem.

**Operacional**: arquivos recebidos, rejeitados e atrasados; throughput; partições com erro; totalizadores; exceções por SLA; códigos de divergência e qualidade por layout.

**Financeiro**: cobrança esperada, pagamento localizado, liquidado e conciliado; valor bruto, tarifa e líquido; pagamentos sem cobrança; cobranças sem pagamento; aging e recuperação.

**Causa raiz**: Pareto das causas, recorrência por sistema, banco e versão de layout, anomalias de volume e valor protegido por regra.

### 11.4 Detalhe da divergência

Exibir lado a lado cobrança esperada e registro recebido:

| Cobrança esperada | Registro recebido |
|---|---|
| Contrato original e normalizado | Contrato original e normalizado |
| Cliente mascarado | Cliente mascarado |
| Parcela e vencimento | Parcela e data recebida |
| Valor decomposto | Valor pago e creditado |
| Origem da referência | Arquivo, lote e linha |

Abaixo: regra e versão, candidatos, conflitos, código, impacto, confiança, linha do tempo, evidências e responsável.

### 11.5 Métricas certificadas

```text
taxa_conciliacao = valor_conciliado / valor_elegivel

taxa_automacao = registros_automaticos / registros_com_decisao

valor_em_risco = valor_sem_correspondencia
               + valor_divergente
               + valor_liquidacao_nao_localizada

aging_medio = media(data_atual - data_primeira_identificacao)
```

Os denominadores devem excluir registros em processamento, fontes atrasadas e dados bloqueados por qualidade, salvo indicação contrária.

### 11.6 Alertas

- Valor divergente acima do limite.
- Queda de matching contra a média histórica.
- Arquivo esperado ausente no SLA.
- Concentração de divergências em um banco ou layout.
- Parcela já conciliada recebendo novo pagamento.
- Pagamento localizado sem crédito no extrato.
- Header/trailer diferente do conteúdo.
- Aumento abrupto de valor médio ou quantidade.

Alertas relacionados devem ser agrupados em incidentes para reduzir ruído.

---

## 12. Fluxos de Negócio

### 12.1 Validação preventiva

```text
Arquivo de cobrança
       ▼
Hash e armazenamento original
       ▼
Layout, header e totalizadores
       ▼
Normalização e snapshot de referência
       ▼
Matching de contrato, cliente e parcela
       ▼
Validação de valor, datas e status
       ▼
Aprovado / Divergente / Exceção
```

### 12.2 Retorno bancário

```text
Retorno bancário + cobrança esperada
                ▼
Identificação por chaves e candidatos
                ▼
Comparação de parcela, valor e ocorrência
                ▼
Conciliado / Ajuste / Não conciliado
                ▼
Evidência + impacto + workflow
```

### 12.3 Extrato e liquidação

```text
Pagamento localizado
       ▼
Lote, conta e data de crédito
       ▼
Valor bruto, tarifa e líquido
       ▼
Janela D+n
       ├── Liquidado e conciliado
       └── Não localizado → recuperação financeira
```

### 12.4 Tratamento e reprocessamento

O operador atribui a exceção, investiga evidências, aprova, rejeita ou solicita ajuste. Reprocessamento cria novo `processamento_id`, preserva resultado anterior, recalcula apenas o escopo selecionado e exige aprovação quando alterar decisão encerrada.

### 12.5 Recuperação financeira

Priorizar por valor em risco, idade, probabilidade de correção, prazo, recorrência, clientes afetados e criticidade do parceiro. A plataforma recomenda a ação; baixa, correção ou cobrança permanecem no sistema autorizado.

---

## 13. Segurança, Governança e Auditoria

### 13.1 Multi-tenancy

Todas as entidades carregam `tenant_id` ou relação equivalente. Row-level security, schema ou banco separado devem ser escolhidos conforme risco e escala. O tenant deriva da identidade autenticada e nunca de um filtro confiado ao navegador.

### 13.2 Identidade e acesso

- SSO OIDC/SAML e MFA.
- RBAC por função e ABAC por carteira, banco, produto ou filial.
- Suporte temporário com aprovação e expiração.
- Separação entre criação de regra, aprovação e decisão de alto valor.
- Auditoria de consultas, exportações e alterações administrativas.

### 13.3 Proteção de dados

- Criptografia em trânsito e repouso.
- Mascaramento de CPF/CNPJ, contas, nomes e contatos.
- Nenhum PAN em claro.
- Tokenização ou hash para chaves quando possível.
- Minimização, retenção e descarte conforme finalidade, contrato e LGPD.
- Dados de demonstração separados de produção.

### 13.4 Evidência imutável

Registrar hash do original, linha e posição, versão do layout, transformação, snapshot de referência, regra, tolerância, candidatos, decisão, usuário, reprocessamento e timestamps.

### 13.5 Governança de regras

```text
Rascunho → Teste com amostra → Aprovação → Publicação
     │                                      │
     └──────── Histórico, vigência e reversão
```

Toda regra deve ter proprietário, descrição, versão, casos de teste, data de vigência e plano de reversão.

---

## 14. Atributos de Qualidade

| Atributo | Meta proposta |
|---|---|
| Disponibilidade do portal | ≥ 99,5% mensal |
| Integridade | 100% dos arquivos com hash e origem |
| Idempotência | Nenhuma duplicidade em retry controlado |
| Escala | 10 milhões de registros por execução particionada |
| Atualização | Resultado disponível até 5 minutos após processamento |
| Explicabilidade | 100% das decisões com regra e campos comparados |
| Isolamento | Nenhuma consulta fora do tenant autorizado |
| Recuperação | Retomar partição sem reiniciar o arquivo |
| Consulta | P95 inferior a 2 segundos em filtros padrão |

### 14.1 Observabilidade técnica e financeira

Monitorar filas, throughput, duração, retries, DLQ, matching, ambiguidade, totalizadores, latência de referência, atraso do dashboard, custo por milhão de registros, valor esperado, recebido, conciliado, divergente e em recuperação.

---

## 15. Integrações e Contratos

### 15.1 Fontes

| Fonte | Integração | Conteúdo |
|---|---|---|
| Sistema de cobrança | API, CDC ou arquivo | Contratos, clientes, parcelas e cobranças |
| Bancos | VAN, SFTP, API ou arquivo | Retornos, pagamentos, tarifas e liquidação |
| Gateway | Eventos, CDC ou API de leitura | Transações, status, NSU e eventos |
| ERP/contábil | API ou arquivo | Títulos, baixa, repasse e contabilização |
| Extrato bancário | Arquivo ou API | Crédito, débito, lote e data |
| Cadastro mestre | API ou snapshot | Identificadores e vigência |

### 15.2 Contrato de resultado

```json
{
  "resultado_id": "uuid",
  "tenant_id": "cliente-123",
  "registro_recebido_id": "uuid",
  "cobranca_esperada_id": "uuid",
  "status": "DIVERGENTE",
  "confianca": "CONFIANCA_ALTA",
  "codigo_divergencia": "D07",
  "valor_esperado": "100.00",
  "valor_recebido": "97.50",
  "valor_diferenca": "2.50",
  "regra_version": "regras-cobranca-12",
  "evidencia_ids": ["uuid"],
  "processamento_id": "uuid"
}
```

### 15.3 API de consulta

| Método | Recurso | Descrição |
|---|---|---|
| `GET` | `/v1/execucoes/{id}` | Status e totais |
| `GET` | `/v1/divergencias` | Lista filtrada |
| `GET` | `/v1/divergencias/{id}` | Detalhe e evidências |
| `GET` | `/v1/contratos/{id}/conciliacao` | Parcelas e recebimentos |
| `GET` | `/v1/arquivos/{id}/qualidade` | Qualidade do arquivo |
| `POST` | `/v1/execucoes/{id}/reprocessar` | Solicitação autorizada |
| `POST` | `/v1/divergencias/{id}/resolver` | Resolução com motivo |
| `GET` | `/v1/relatorios/financeiro` | Relatório governado |

A API é somente leitura para dados financeiros por padrão. Workflow não executa baixa diretamente sem integração autorizada.

---

## 16. Roadmap e Empacotamento Comercial

### Fase 1 — Prova de valor

Um layout de retorno, uma fonte de cobrança esperada, contratos e parcelas sintéticos, matching determinístico, divergências de contrato/parcela/valor, dashboard, evidências e processamento idempotente.

### Fase 2 — Operação produtiva

Múltiplos bancos e carteiras, filas, particionamento, ingestão incremental, workflow, alertas, SLA, extrato, liquidação, exportações e catálogo de regras.

### Fase 3 — Inteligência financeira

Anomalias, causa raiz, previsão de valor em risco, priorização de recuperação, benchmark privado, BI embedded e relatórios agendados.

### Fase 4 — Escala comercial

Onboarding self-service, biblioteca de conectores, configuração por plano, API pública, webhooks, white-label, SLA de frescor e cobrança por volume ou módulos.

### Pacotes sugeridos

| Pacote | Conteúdo |
|---|---|
| Essential | Ingestão, validação estrutural, matching básico e relatórios |
| Control | Regras avançadas, conciliação, exceções, alertas e auditoria |
| Intelligence | BI, anomalias, recuperação, benchmarks e relatórios executivos |
| Enterprise | Alto volume, SSO, SLA, conectores, white-label e API |

---

## 17. Decisões Arquiteturais (ADRs)

### ADR-001: Sistema paralelo e independente

**Decisão**: manter resultados e evidências próprios, sem alterar diretamente contratos, parcelas ou saldos da origem.

**Consequência**: menor risco financeiro; ações efetivas exigem integração autorizada.

### ADR-002: Original imutável

**Decisão**: preservar arquivo, hash, metadados e versões; normalizações geram novas representações.

**Consequência**: auditoria e replay confiáveis, com maior custo de armazenamento.

### ADR-003: Matching em camadas

**Decisão**: usar chaves determinísticas primeiro; candidatos aproximados ficam em revisão, salvo política formal.

**Consequência**: maior segurança e explicabilidade; algumas exceções continuam manuais.

### ADR-004: Modelo canônico preservando origem

**Decisão**: normalizar conceitos equivalentes mantendo valor bruto, posição, transformação e fonte.

**Consequência**: regras reutilizáveis entre bancos e layouts.

### ADR-005: Particionamento idempotente

**Decisão**: processar blocos, persistir checkpoints e proteger resultados por chaves de deduplicação.

**Consequência**: escala e retomada; exige consolidação global de totais e sequências.

### ADR-006: BI sobre camada semântica

**Decisão**: portal, BI e exportações consomem métricas certificadas com fórmula, origem, versão e qualidade.

**Consequência**: indicadores consistentes e governados.

### ADR-007: Regras versionadas

**Decisão**: layout, referência, tolerância e política usados em uma execução são imutáveis e identificáveis.

**Consequência**: decisões reproduzíveis e auditáveis.

---

## 18. Roteiro de Demonstração Comercial

1. Abrir a visão executiva com carteira, taxa de conciliação e valor em risco.
2. Mostrar que um banco ou layout concentra a degradação.
3. Abrir uma cobrança e comparar contrato, cliente, parcela e valor.
4. Demonstrar parcela deslocada e pagamento real não conciliado.
5. Demonstrar valor recebido diferente por tarifa ou desconto sem composição.
6. Ordenar a fila por valor, aging e impacto.
7. Mostrar hash, linha, regra, snapshot, evidência e usuário.
8. Exibir o BI de causa raiz e o valor protegido.
9. Apresentar evolução para alertas, recuperação e BI embedded.

A demonstração deve usar dados sintéticos, mas proporções e causas próximas da operação real. A mensagem central é:

> **O Sistema Confiança encontra o dinheiro que a conciliação não consegue explicar, mostra a causa com evidência e orienta o que recuperar primeiro.**

---

## 19. Premissas e Próximas Decisões

### 19.1 Premissas

- O cliente possui fonte de contratos, clientes e parcelas, mesmo que em arquivos.
- Retorno bancário pode ser associado a arquivo, lote ou período.
- Originais podem ser preservados em armazenamento durável.
- Tolerâncias e regras financeiras serão validadas pelo negócio.
- A camada analítica pode ter eventualidade controlada com frescor visível.
- Existe equipe responsável por revisar ambiguidades e exceções.

### 19.2 Decisões necessárias

| Tema | Pergunta |
|---|---|
| Volume | Quantos registros por arquivo, dia e pico? |
| Fontes | Quais bancos e layouts entram primeiro? |
| Referência | Qual sistema define contrato, cliente, parcela e valor? |
| Matching | Quais chaves são confiáveis? |
| Financeiro | Como juros, multa, desconto, tarifa e arredondamento são compostos? |
| SLA | Qual prazo para validar e resolver? |
| Ação | Apenas recomenda ou inicia workflow externo? |
| Retenção | Por quanto tempo manter arquivos e evidências? |
| BI | Portal, embedded, externo ou combinação? |
| Comercial | Volume, módulo, usuário, tenant ou valor recuperado? |

### 19.3 Primeiro incremento recomendado

Construir um vertical slice com um layout de retorno, uma fonte de cobrança esperada, até cinco milhões de registros sintéticos, matching por contrato/cliente/parcela, tolerância de valor, três divergências demonstráveis, resultado idempotente, dashboard, fila e reprocessamento de partição.

---

## 20. Glossário

| Termo | Definição |
|---|---|
| **Arquivo de cobrança** | Arquivo de cobranças, parcelas, títulos ou retornos |
| **Conciliação** | Comparação entre esperado, recebido, liquidado e contabilizado |
| **Matching** | Associação de registro recebido à cobrança esperada |
| **Chave de negócio** | Identificador como contrato, título, parcela ou nosso número |
| **Valor em risco** | Valor divergente, sem correspondência ou com liquidação ausente |
| **Divergência** | Diferença entre campos ou estados de fontes relacionadas |
| **Tolerância** | Variação permitida por regra de comparação |
| **Evidência** | Dado ou comparação que sustenta decisão |
| **Idempotência** | Repetição sem duplicar efeito financeiro |
| **Landing zone** | Armazenamento inicial dos dados originais |
| **Data mart** | Modelo analítico orientado a uma necessidade de negócio |
| **BI** | Business Intelligence para análise e decisão |
| **DLQ** | Fila de mensagens que falharam após tentativas controladas |
| **Aging** | Idade de uma pendência |
| **CNAB 240/400** | Padrões de arquivos bancários de 240 ou 400 posições |
| **Snapshot** | Cópia consistente de dados de referência |
| **Reprocessamento** | Nova execução preservando o resultado anterior |
| **Tenant** | Cliente ou organização isolada na plataforma |
| **Fonte de verdade** | Sistema autorizado que define estado financeiro ou cadastral |
