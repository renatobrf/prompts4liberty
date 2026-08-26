# Assessment de Arquitetura: Data Lake para Repouso de Dados Históricos do DB2

## Camada de Arquivamento, Consulta Eventual e Redução de Crescimento do Banco Transacional

| Atributo | Valor |
|---|---|
| Versao | 1.0 |
| Status | Proposta para validacao |
| Dominio | Dados historicos, pagamentos, auditoria e analytics |
| Sistema de origem | DB2 legado do Gateway de Pagamentos |
| Objetivo | Reduzir crescimento, carga e custo do DB2 sem perder integridade ou auditabilidade |
| Referencias | [Export de Dados Legacy](./arq-data-legacy-export.md) · [Arquitetura do Gateway](./gateway-pagamentos-arquitetura-software.md) |
| Decisao preliminar | Adotar data lake governado com carga historica inicial e ingestao incremental |

---

## Indice

1. [Resumo Executivo](#1-resumo-executivo)
2. [Contexto e Problema](#2-contexto-e-problema)
3. [Objetivos e Nao Objetivos](#3-objetivos-e-nao-objetivos)
4. [Criterios de Decisao](#4-criterios-de-decisao)
5. [Opcoes Avaliadas](#5-opcoes-avaliadas)
6. [Arquitetura Recomendada](#6-arquitetura-recomendada)
7. [Estrategia de Migracao](#7-estrategia-de-migracao)
8. [Modelo de Dados e Particionamento](#8-modelo-de-dados-e-particionamento)
9. [Consistencia, Integridade e Reconciliacao](#9-consistencia-integridade-e-reconciliacao)
10. [Ciclo de Vida e Retencao](#10-ciclo-de-vida-e-retencao)
11. [Seguranca, Compliance e Governanca](#11-seguranca-compliance-e-governanca)
12. [Acesso e Experiencia de Consulta](#12-acesso-e-experiencia-de-consulta)
13. [Operacao e Observabilidade](#13-operacao-e-observabilidade)
14. [Atributos de Qualidade](#14-atributos-de-qualidade)
15. [Riscos e Mitigacoes](#15-riscos-e-mitigacoes)
16. [Roadmap e Criterios de Aceite](#16-roadmap-e-criterios-de-aceite)
17. [Decisoes Arquiteturais (ADRs)](#17-decisoes-arquiteturais-adrs)
18. [Premissas e Proximas Decisoes](#18-premissas-e-proximas-decisoes)
19. [Glossario](#19-glossario)

---

## 1. Resumo Executivo

O DB2 concentra anos de operacoes transacionais, arquivos, eventos, conciliacoes e auditoria. O crescimento exponencial aumenta o custo de armazenamento, torna consultas mais lentas, amplia janelas de backup e dificulta a operacao do gateway.

A recomendacao deste assessment e criar um **data lake governado para dados de longa data e baixa frequencia de acesso**, mantendo no DB2 apenas o conjunto necessario para operacao corrente, consultas de baixa latencia e obrigações de curto prazo.

A solucao nao deve ser apenas um novo destino para snapshots. Ela deve combinar:

- carga historica inicial particionada;
- ingestao incremental depois da data de corte;
- formato colunar e aberto, como Parquet com Iceberg;
- camadas de dados com diferentes niveis de confianca e retenção;
- catalogo, qualidade, linhagem e politica de acesso;
- consultas SQL sobre dados historicos sem pressionar o DB2;
- reconciliacao antes de qualquer expurgo na origem;
- trilha de auditoria e preservacao sob legal hold.

### 1.1 Decisao recomendada

```text
DB2 operacional
      │
      ├── Carga historica por lotes consistentes ──┐
      │                                             ▼
      └── CDC ou delta incremental ──────────► Data Lake governado
                                                │
                                                ├── Bronze: original
                                                ├── Silver: normalizado
                                                ├── Gold: consultavel
                                                └── Archive: baixa frequencia
                                                         │
                                       SQL / BI / auditoria / reprocessamento
```

A retirada física de dados do DB2 somente ocorre após comprovar completude, consistência, capacidade de consulta e aprovação de compliance. O data lake passa a ser a camada de repouso, mas nao substitui automaticamente o sistema de registro financeiro.

### 1.2 Conclusao de adequacao

| Dimensao | Avaliacao |
|---|---|
| Alivio de crescimento do DB2 | **Alta aderencia**, condicionado a uma politica real de expurgo |
| Reducao de custo | **Alta aderencia** em armazenamento de baixa frequencia |
| Consulta historica | **Alta aderencia** com engine SQL e tabelas abertas |
| Integridade financeira | **Aderencia condicionada** a snapshot consistente e reconciliação |
| Auditoria | **Alta aderencia** com dados imutáveis, manifestos e retenção WORM |
| Baixa latencia transacional | **Nao aplicavel**; DB2 deve continuar atendendo o hot path |
| Complexidade operacional | **Media/alta**; exige plataforma de dados e governanca |

---

## 2. Contexto e Problema

### 2.1 Situacao atual

O DB2 atua simultaneamente como banco transacional, historico operacional, fonte de auditoria e base para consultas. Esse acoplamento faz com que dados raramente acessados concorram com operacoes de pagamento e processamento de arquivos.

O problema nao e resolvido apenas com snapshots:

- cada snapshot replica o volume acumulado;
- snapshots podem consumir I/O e janela de backup;
- a mesma informacao pode existir em varias copias sem catalogo claro;
- snapshot nao oferece necessariamente consulta eficiente por periodo ou dominio;
- nao existe, por si só, uma politica de ciclo de vida ou expurgo;
- uma copia inconsistente pode preservar um erro sem fornecer evidência de origem.

### 2.2 Dados candidatos

| Domínio | Exemplos | Prioridade |
|---|---|---|
| Transacoes | Cartao, boleto, PIX, TED, DOC, status e autorizacao | Alta |
| Arquivos | Remessa, retorno, extrato, posição e metadados | Alta |
| Auditoria | Hiker, eventos de processamento, acessos e alteracoes | Alta |
| Conciliacao | Matching, liquidacao, divergencias e evidencias | Alta |
| Operacional | Erros, tentativas, filas e checkpoints antigos | Media |
| Referencia | Dimensoes, cadastros historicos e versoes de regra | Alta |
| Dados pessoais | Cliente, pagador, beneficiario e identificadores | Condicionada |

A lista definitiva deve ser baseada em volume, frequência de acesso, obrigação de retenção, dependências referenciais e capacidade de reconstrução do estado.

### 2.3 Dados que devem permanecer no DB2

O DB2 deve manter, no mínimo:

- transacoes em processamento ou ainda sujeitas a alteração;
- janela operacional definida pelo negócio;
- estados necessários para APIs de baixa latência;
- referências necessárias para processamento corrente;
- dados com obrigação de consulta imediata, até existir serviço equivalente;
- índices e agregações usadas pelo caminho transacional;
- registros sob investigação que ainda exigem atualização autorizada.

A data de corte deve ser definida por entidade e estado, nao apenas por uma data global. Uma transacao antiga ainda aberta nao pode ser arquivada como se fosse imutável.

---

## 3. Objetivos e Nao Objetivos

### 3.1 Objetivos

| # | Objetivo |
|---|---|
| O1 | Reduzir o crescimento do DB2 e a pressão sobre I/O, backup e consultas |
| O2 | Manter dados historicos acessiveis por SQL, BI e auditoria |
| O3 | Preservar integridade, linhagem, evidências e chaves de negócio |
| O4 | Substituir snapshots indiscriminados por armazenamento particionado e governado |
| O5 | Permitir carga historica inicial sem interromper o gateway |
| O6 | Manter o data lake atualizado depois da migração inicial |
| O7 | Permitir reprocessamento sem consultar repetidamente o DB2 |
| O8 | Reduzir custo de armazenamento para dados de acesso eventual |

### 3.2 Nao objetivos

- substituir o DB2 como sistema transacional no primeiro momento;
- executar autorização, captura, estorno ou liquidação no data lake;
- criar uma cópia sem catálogo, SLA ou proprietário;
- apagar dados da origem apenas porque a exportação terminou;
- usar o data lake como fila transacional ou cache de baixa latência;
- alterar dados históricos sem gerar nova versão e trilha de auditoria;
- replicar dados pessoais além da finalidade e retenção aprovadas.

---

## 4. Criterios de Decisao

A solução deve ser avaliada por estes critérios, com pesos definidos pelo negócio:

| Critério | Pergunta |
|---|---|
| Integridade | Consigo provar que nada foi perdido, duplicado ou associado à data errada? |
| Consistencia | A exportação representa um estado coerente entre tabelas relacionadas? |
| Impacto no DB2 | A leitura interfere no gateway e nas janelas críticas? |
| Acessibilidade | Um auditor consegue consultar dados antigos sem restaurar backup? |
| Custo | O custo total inclui armazenamento, consulta, rede, processamento e operação? |
| Retenção | É possível aplicar retenção, legal hold e descarte verificável? |
| Segurança | Há isolamento, criptografia, mascaramento e controle por finalidade? |
| Evolucao | Novas tabelas e versões podem ser adicionadas sem reescrever a plataforma? |
| Recuperacao | É possível reconstruir ou corrigir uma partição com falha? |
| Dependencia | A solução evita dependência excessiva de ferramenta proprietária? |

O custo deve ser calculado por padrão de acesso. Armazenamento barato pode deixar de ser barato quando há consultas frequentes, leitura de muitos arquivos pequenos, egress ou reprocessamentos constantes.

---

## 5. Opcoes Avaliadas

### 5.1 Opção A: Continuar com snapshots do DB2

**Descrição**: gerar cópias periódicas completas ou incrementais do banco e mantê-las em backup ou storage.

| Vantagens | Limitações |
|---|---|
| Baixa mudança no processo atual | Replica dados e crescimento ao longo do tempo |
| Recuperação familiar ao DBA | Consulta histórica exige restore ou ambiente DB2 auxiliar |
| Boa fidelidade ao banco | Não separa dados quentes, mornos e frios |
| Menor mudança inicial | Não resolve governança, catálogo ou acesso analítico |

**Avaliação**: adequado como mecanismo de disaster recovery e retenção de curto prazo, mas insuficiente como estratégia de repouso de dados históricos.

### 5.2 Opção B: Export batch para object storage

**Descrição**: extrair tabelas em lotes para arquivos Parquet em storage de objetos, com manifestos e consultas sob demanda.

| Vantagens | Limitações |
|---|---|
| Simples e econômico para histórico frio | Atualização incremental precisa ser projetada |
| Baixa dependência do banco na consulta | Sem formato de tabela, merges e evolução são difíceis |
| Parquet reduz volume e leitura | Pode criar partições inconsistentes ou duplicadas |
| Bom ponto de partida | Governança pode ficar manual |

**Avaliação**: adequado para PoC e carga inicial, desde que acompanhado de catálogo, qualidade e estratégia incremental.

### 5.3 Opção C: Data lake governado com tabela aberta

**Descrição**: object storage como camada durável, Parquet como formato físico e Iceberg, Delta Lake ou Hudi como formato de tabela, com catálogo e engine SQL.

| Vantagens | Limitações |
|---|---|
| Consulta histórica sem restaurar DB2 | Maior complexidade de plataforma |
| Evolução de schema e particionamento | Requer governança de catálogo e jobs |
| Upsert, snapshot e time travel controlados | Custo de compactação e manutenção |
| Integração com BI e processamento distribuído | Exige conhecimento operacional |
| Base para carga inicial e incremental | Nao resolve sozinho a consistência da origem |

**Avaliação**: **opção recomendada** para substituir snapshots como camada de repouso, mantendo a liberdade de trocar engine de consulta.

### 5.4 Opção D: Data warehouse como arquivo principal

**Descrição**: carregar todo o histórico diretamente em warehouse colunar.

| Vantagens | Limitações |
|---|---|
| Consulta SQL e BI simples | Custo maior para retenção longa e dados raramente acessados |
| Governança e modelos analíticos maduras | Pode exigir cópia de dados antes da carga |
| Bom desempenho para agregações | Menor flexibilidade para originais e replay |

**Avaliação**: pode ser camada Gold ou data mart, mas nao deve ser o único repouso de originais e histórico regulatório.

### 5.5 Comparativo

| Opção | Alivia DB2 | Consulta histórica | Incremental | Governança | Recomendação |
|---|---:|---:|---:|---:|---|
| Snapshots | Baixa | Baixa | Media | Baixa | Apenas backup/DR |
| Batch em object storage | Alta | Media | Media | Media | PoC e carga inicial |
| Data lake governado | Alta | Alta | Alta | Alta | **Recomendada** |
| Warehouse | Alta | Alta | Alta | Alta | Camada de consumo |

---

## 6. Arquitetura Recomendada

### 6.1 Visao logica

```text
┌────────────────────────────────────────────────────────────────────┐
│ Consumidores                                                       │
│ Query service · BI · auditoria · suporte · reprocessamento         │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Camada de consulta                                                │
│ SQL engine · catálogo · views governadas · data marts             │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Tabelas abertas                                                   │
│ Iceberg/Delta/Hudi sobre Parquet · snapshots · compaction         │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Data lake                                                         │
│ Raw imutável · standardized · curated · quarantine · archive      │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▲
                               │ jobs, CDC, manifests, checkpoints
┌────────────────────────────────────────────────────────────────────┐
│ Ingestao                                                           │
│ DB2 unload/export · CDC · delta por watermark · orquestrador       │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▲
┌────────────────────────────────────────────────────────────────────┐
│ DB2 operacional                                                   │
│ Transacoes · arquivos · Hiker · eventos · conciliacao              │
└────────────────────────────────────────────────────────────────────┘
```

### 6.2 Camadas do data lake

| Camada | Conteúdo | Mutabilidade | Usuários |
|---|---|---|---|
| `landing` | Arquivo recebido, dump ou lote original | Append-only | Pipeline e auditoria técnica |
| `raw` | Dados extraídos com schema de origem | Append-only | Replay e investigação |
| `standardized` | Tipos, nomes e metadados padronizados | Nova versão | Engenharia e qualidade |
| `curated` | Entidades e relações prontas para consulta | Controlada por tabela | BI, suporte e auditoria |
| `quarantine` | Lotes incompletos ou com falha de qualidade | Append-only | Data quality e suporte |
| `archive` | Dados frios com política de acesso restrita | Imutável | Auditoria e recuperação excepcional |

A camada `raw` deve ser preservada por período compatível com o risco e a capacidade de replay. A camada `curated` pode ser reprocessada, mas o seu resultado deve apontar para a versão de origem, regra e job utilizados.

### 6.3 Componentes

#### 6.3.1 Extrator DB2

Responsável pela carga inicial e, quando necessário, por deltas baseados em watermark. Deve usar leitura controlada, consultas por chave indexada ou utilitário nativo validado pelo DBA.

O extrator precisa registrar:

- `export_id` e `batch_id`;
- tabela, predicado e data de corte;
- janela de execução;
- isolamento de leitura utilizado;
- quantidade e soma de controle por partição;
- último watermark ou posição de log;
- duração, taxa de leitura e impacto observado;
- versão da consulta ou configuração.

#### 6.3.2 Captura incremental

Preferir CDC baseado em logs de transação do DB2 quando houver suporte aprovado no ambiente. Quando CDC nao for viável, usar delta por coluna monotônica de alteração, com janela de sobreposição e deduplicação.

A captura incremental deve tratar:

- inserts, updates e deletes;
- transações tardias;
- alterações fora de ordem;
- clock skew entre sistemas;
- reprocessamento após falha;
- retenção do log de origem;
- consistência entre tabelas dependentes.

#### 6.3.3 Orquestrador

Coordena extração, validação, publicação, compactação, catálogo, alertas e reconciliação. Cada etapa deve ser retomável e possuir estado persistente.

#### 6.3.4 Object storage

Armazena arquivos e tabelas abertas com versionamento, criptografia, políticas de retenção e bloqueio de exclusão para dados sob preservação.

#### 6.3.5 Catalogo e qualidade

Mantém schemas, proprietários, classificação de dados, linhagem, SLA de atualização, regras de qualidade, custo e política de acesso.

#### 6.3.6 Engine de consulta

Fornece SQL para dados históricos e agregados. Deve aplicar filtros de tenant, finalidade e período antes de executar leituras amplas.

---

## 7. Estrategia de Migracao

### 7.1 Regra de ouro

A migração deve separar **copiar**, **validar**, **servir** e **expurgar**. Uma etapa nao autoriza automaticamente a próxima.

### 7.2 Fase 0: Descoberta e classificação

- inventariar tabelas, colunas, chaves e dependências;
- medir volume físico e lógico;
- identificar frequência de acesso e consultas existentes;
- classificar dados pessoais, financeiros e regulatórios;
- localizar colunas de criação, alteração e exclusão;
- verificar índices e impacto das consultas de extração;
- definir proprietário e período de retenção por entidade.

**Saída**: matriz de classificação e mapa de dependências.

### 7.3 Fase 1: PoC representativa

Selecionar uma tabela menor e uma tabela relacionada, por exemplo eventos de processamento e transações. A PoC deve validar:

- extração consistente;
- escrita Parquet e tabela aberta;
- leitura por SQL;
- schema evolution;
- checksum e contagem;
- controle de acesso;
- custo de armazenamento e consulta;
- tempo de recuperação de uma amostra;
- comportamento de reprocessamento.

### 7.4 Fase 2: Carga historica inicial

Dividir o histórico em intervalos determinísticos, preferencialmente por data e por chave técnica. Cada lote deve ser independente e possuir manifest.

```text
DB2
 │
 ├─ janela 1: data inicial até corte A ──► landing/raw/batch-001
 ├─ janela 2: corte A até corte B ──────► landing/raw/batch-002
 └─ janela 3: corte B até data final ───► landing/raw/batch-003
                                              │
                                              ▼
                                  standardized → curated
```

O predicado de extração deve ser estável e indexado. Evitar paginação por `OFFSET` em tabelas grandes; preferir range scan por chave ou por coluna de corte.

### 7.5 Fase 3: Janela de convergência

Enquanto a carga histórica ocorre, novas alterações continuam chegando ao DB2. É necessário capturar a diferença entre o início da carga e o momento de corte final.

```text
T0: inicia carga histórica
T1: captura mudanças desde T0 em CDC ou delta
T2: valida histórico e incremental
T3: aplica incremental até atingir watermark de convergência
T4: congela apenas a partição elegível para expurgo
```

Sem esta etapa, o lake pode conter uma fotografia antiga e perder alterações ocorridas durante a migração.

### 7.6 Fase 4: Servir consultas

Antes de remover dados do DB2:

- publicar tabelas e views governadas;
- migrar consultas históricas conhecidas;
- testar tempos de resposta;
- comparar resultados com o DB2;
- documentar diferença entre consulta eventual e transacional;
- habilitar fallback temporário para a origem.

### 7.7 Fase 5: Expurgo controlado

O expurgo é uma operação separada, aprovada por DBA, dono do dado, segurança, compliance e negócio. Deve ocorrer por partição ou conjunto de tabelas relacionado, com backup e evidência de aprovação.

Depois do expurgo:

- manter janela de retenção no backup ou archive conforme política;
- monitorar erros de consulta e reconciliação;
- verificar redução de espaço e tempo de backup;
- manter procedimento documentado de restauração excepcional.

### 7.8 Fase 6: Operação contínua

Após o corte, a ingestão incremental mantém o lake atualizado. O processo deve incluir compactação, validação, catalogação, reconciliação, ajuste de partições e aplicação de políticas de ciclo de vida.

---

## 8. Modelo de Dados e Particionamento

### 8.1 Entidades de controle

| Entidade | Finalidade |
|---|---|
| `export_execution` | Execução, escopo, configuração e status |
| `export_batch` | Lote, intervalo, contagem e checksums |
| `source_watermark` | Posição ou data processada por origem |
| `schema_version` | Schema original e schema normalizado |
| `quality_result` | Regras e resultados de qualidade |
| `reconciliation_result` | Comparação DB2 versus lake |
| `retention_policy` | Regra por domínio e classificação |
| `legal_hold` | Bloqueio de expurgo por motivo e prazo |
| `access_audit` | Consultas, exportações e aprovações |

Estas entidades podem ficar em um catálogo operacional separado do armazenamento de dados, sem misturar controle de pipeline com fatos financeiros.

### 8.2 Chaves e metadados obrigatórios

Cada registro ou arquivo deve carregar, quando aplicável:

- `source_system`;
- `source_table`;
- `source_primary_key`;
- `tenant_id` ou parceiro;
- `event_time` e `ingestion_time`;
- `export_id`, `batch_id` e `processing_id`;
- `schema_version`;
- `record_hash`;
- `operation` (`I`, `U`, `D`);
- `source_lsn` ou watermark equivalente;
- `correlation_id`;
- classificação de dado e política de retenção.

### 8.3 Particionamento

Particionar por colunas usadas em filtros frequentes, normalmente domínio, ano e mês de data de negócio. Evitar particionar por colunas de alta cardinalidade ou criar milhares de diretórios pequenos.

```text
lake://pagamentos/
├── raw/source=db2/table=transacoes/year=2023/month=06/
├── standardized/domain=pagamentos/entity=transacao/year=2023/month=06/
├── curated/entity=transacao/year=2023/month=06/day=30/
├── curated/entity=liquidacao/year=2023/month=06/
└── archive/domain=auditoria/year=2020/
```

A coluna de partição nao precisa ser a mesma data usada para retenção. `data_transacao`, `data_evento`, `data_liquidacao` e `ingestion_date` possuem significados distintos e devem ser documentadas.

### 8.4 Formato e tabela aberta

- Parquet como formato físico colunar.
- Compressão Snappy para uso geral; avaliar Zstandard para dados mais frios.
- Row groups dimensionados por benchmark, evitando arquivos muito pequenos.
- Iceberg, Delta Lake ou Hudi conforme compatibilidade do ecossistema existente.
- Uma única tecnologia de tabela aberta como padrão inicial, evitando mistura sem necessidade.
- Compactação periódica para reduzir small files.
- Schema evolution explícita e compatível.

A escolha entre Iceberg, Delta e Hudi deve ser feita por compatibilidade com engine de consulta, CDC, operação e skills disponíveis. O princípio importante é manter metadados de tabela e evitar um conjunto de arquivos sem transação lógica.

### 8.5 Relacionamentos

A modelagem deve preservar as chaves de negócio e técnicas do DB2. Relacionamentos entre transação, arquivo, Hiker, evento, conciliação e liquidação devem ser consultáveis sem depender do banco original.

Não remover chaves estrangeiras lógicas apenas porque o storage é orientado a arquivos. A qualidade deve verificar referências órfãs e cardinalidades esperadas.

---

## 9. Consistencia, Integridade e Reconciliacao

### 9.1 Consistencia da carga inicial

Um snapshot lógico precisa definir o instante ou faixa de consistência. Ler cada tabela em horários diferentes pode produzir relações impossíveis entre transação, evento e liquidação.

Opções, em ordem de preferência:

1. mecanismo de snapshot consistente suportado pelo DB2;
2. exportação coordenada com ponto de consistência e LSN/SCN;
3. janela controlada com baixa mutabilidade, mais CDC para alterações;
4. extração por estado encerrado e data de negócio, com validação posterior.

`WITH UR` pode reduzir bloqueios, mas não deve ser tratado como garantia de snapshot consistente. O nível de isolamento e o comportamento devem ser confirmados com o DBA e testados no DB2 específico.

### 9.2 Manifesto por lote

```json
{
  "export_id": "exp-20260826-001",
  "batch_id": "batch-transacoes-2023-06",
  "source": {
    "system": "db2-gateway",
    "table": "TRANSACOES",
    "predicate": "data_criacao >= 2023-06-01 AND data_criacao < 2023-07-01",
    "isolation": "defined-by-dba",
    "watermark": "source-position-123"
  },
  "schema_version": "transacoes-v3",
  "record_count": 1000000,
  "sum_controls": {
    "valor_bruto": "123456789.90",
    "valor_liquido": "122000000.10"
  },
  "files": [
    {
      "path": "curated/entity=transacao/year=2023/month=06/part-0001.parquet",
      "record_count": 250000,
      "sha256": "sha256-value"
    }
  ],
  "created_at": "2026-08-26T12:00:00Z"
}
```

O manifesto deve ser armazenado em local governado e assinado ou protegido contra alteração conforme o nível de auditoria exigido.

### 9.3 Checks de reconciliação

| Check | Descrição |
|---|---|
| Contagem | DB2, raw, standardized e curated por lote e partição |
| Soma | Valores financeiros por moeda, tipo e período |
| Chaves | Ausência de duplicidades e chaves ausentes |
| Referências | Integridade entre transação, arquivo, evento e liquidação |
| Operações | Inserts, updates e deletes aplicados corretamente |
| Intervalos | Mínimo e máximo de datas, NSU e watermark |
| Hash | Digest do arquivo e amostras de registros |
| Qualidade | Nulos, domínios, tipos e regras de negócio |
| Consulta | Resultado equivalente para consultas de referência |

Uma contagem igual nao prova integridade. Deve haver controles financeiros, chaves, intervalos e amostras de conteúdo.

### 9.4 Estados da execução

```text
PLANEJADA → EXTRAINDO → RECEBIDA → VALIDANDO → PUBLICADA
                              │          │
                              ├──────────┴→ QUARENTENA
                              └───────────→ FALHA_REPROCESSAVEL

PUBLICADA → CONVERGIDA → ELEGIVEL_EXPURGO → EXPURGO_APROVADO → EXPURGADA
```

`EXPURGADA` nao deve ser emitido automaticamente por um job de ingestão. Requer aprovação e evidência específica.

---

## 10. Ciclo de Vida e Retencao

### 10.1 Classes de acesso

| Classe | Perfil | Local sugerido |
|---|---|---|
| Hot | Acesso frequente e consultas recentes | DB2 e/ou serving de baixa latência |
| Warm | Acesso operacional eventual | Curated em storage de consulta |
| Cold | Auditoria e investigação rara | Archive com recuperação programada |
| Legal hold | Sem expurgo autorizado | Storage imutável com retenção bloqueada |

Os nomes das classes sao conceituais. A política real deve considerar o provedor de storage, latência de restauração, custos e obrigações contratuais.

### 10.2 Política por domínio

Cada domínio deve definir:

- período de permanência no DB2;
- período em curated;
- período em raw;
- período em archive;
- prazo de recuperação esperado;
- proprietário do dado;
- justificativa legal ou operacional;
- condição de descarte;
- procedimento de destruição verificável.

Nao aplicar uma única retenção global a transações, logs, arquivos e dados pessoais.

### 10.3 Expurgo

Expurgo deve ser:

- aprovado por workflow;
- bloqueado quando houver `legal_hold`;
- executado por partição ou entidade completa;
- registrado no catálogo e no log de auditoria;
- validado após a execução;
- compatível com backups, réplicas e caches;
- acompanhado de evidência de que a cópia de referência está acessível.

O lake também precisa de expurgo. Transferir os dados do DB2 para storage barato sem política de retenção apenas muda o lugar do problema.

---

## 11. Seguranca, Compliance e Governanca

### 11.1 Proteção de dados

- Criptografia em trânsito e repouso.
- Chaves gerenciadas com rotação e separação de funções.
- Mascaramento de CPF/CNPJ, contas, nomes e identificadores em ambientes de teste.
- Tokenização ou cifragem de dados sensíveis quando a consulta nao exigir valor original.
- Proibição de PAN em claro em arquivos, logs, tabelas e amostras.
- Separação entre produção, homologação e dados sintéticos.
- Política de minimização alinhada à LGPD e à finalidade do domínio.

### 11.2 Controle de acesso

- Identidade federada e MFA para operadores.
- RBAC para funções de engenharia, dados, auditoria e suporte.
- ABAC ou filtros por tenant, parceiro, domínio e classificação.
- Acesso de escrita no raw restrito ao pipeline.
- Acesso de expurgo separado do acesso de ingestão.
- Exportação de dados sujeita a aprovação e auditoria.
- Consultas amplas e restaurações em archive monitoradas.

### 11.3 Imutabilidade e evidência

A camada raw e os manifestos devem usar versionamento e, para dados regulatórios, mecanismo de retenção que impeça alteração ou exclusão antes do prazo. Eventuais correções devem criar nova versão, mantendo o original.

### 11.4 Governança de schema

Mudanças devem registrar:

- coluna adicionada, removida ou alterada;
- compatibilidade com consumidores;
- transformação aplicada;
- versão de origem e destino;
- plano de migração;
- responsável e aprovação;
- período de coexistência.

### 11.5 Compliance

A arquitetura deve ser revisada por segurança, privacidade, auditoria e compliance. As referências regulatórias do gateway, PCI-DSS, LGPD e políticas internas devem ser confirmadas para cada classe de dado. Este documento nao substitui parecer jurídico ou regulatório.

---

## 12. Acesso e Experiencia de Consulta

### 12.1 Padrao de consulta

O consumidor deve acessar o histórico por uma camada de consulta governada, e nao por credenciais diretas no bucket. Essa camada aplica catálogo, autorização, limites, auditoria e metadados de frescor.

```text
Usuário / BI / serviço
          │
          ▼
Query service + autorização + catálogo
          │
          ▼
Views certificadas / data marts
          │
          ▼
Tabelas abertas no data lake
```

### 12.2 Casos de uso

| Caso | Camada recomendada |
|---|---|
| Consulta de transação recente | DB2 ou API operacional |
| Relatório de vários anos | Curated/data mart |
| Investigação de evento | Curated + raw sob permissão |
| Replay de transformação | Raw + metadados de execução |
| Auditoria excepcional | Archive com recuperação controlada |
| Treinamento e demonstração | Dados sintéticos separados |

### 12.3 Contrato de consulta

Toda resposta deve informar:

- período e filtro aplicados;
- horário de atualização;
- origem e versão do schema;
- qualidade e eventuais lacunas;
- se o dado veio de hot, warm ou archive;
- identificador da consulta para auditoria.

A interface deve sinalizar que dados arquivados podem ser eventualmente consistentes e ter maior latência de recuperação.

### 12.4 Fallback

Durante a transição, uma consulta histórica pode consultar primeiro curated e recorrer ao DB2 somente quando o catálogo indicar que a partição ainda nao foi migrada. O fallback deve ser temporário e observável, pois consultas analíticas recorrentes no DB2 recriam o problema.

---

## 13. Operacao e Observabilidade

### 13.1 Métricas da ingestão

- atraso entre DB2 e lake;
- watermark atual e esperado;
- registros e bytes por segundo;
- backlog de CDC ou delta;
- duração por tabela e partição;
- taxa de retry e DLQ;
- small files por domínio;
- falhas de schema;
- custo por lote e por milhão de registros.

### 13.2 Métricas de qualidade

- contagem e soma por camada;
- percentual de registros rejeitados;
- chaves duplicadas e órfãs;
- nulos inesperados;
- divergência de totalizadores;
- atraso de tabelas dependentes;
- taxa de consultas com fallback para DB2;
- partições sem catálogo ou sem owner.

### 13.3 Alertas

- CDC atrasado além do SLA;
- lote publicado sem manifesto;
- diferença de contagem ou valor acima da tolerância;
- falha de compactação;
- schema incompatível;
- arquivo duplicado ou watermark regressivo;
- consulta tentando ler raw sem permissão;
- objeto próximo do vencimento sem decisão de retenção;
- expurgo executado fora de janela aprovada.

### 13.4 Runbooks necessários

1. Reprocessar uma partição com falha.
2. Corrigir schema incompatível sem perder dados.
3. Recuperar uma partição do archive.
4. Reconciliar diferença entre DB2 e curated.
5. Retomar CDC após perda de conexão.
6. Isolar dado contaminado em quarantine.
7. Suspender expurgo por legal hold.
8. Restaurar consulta durante indisponibilidade do lake.
9. Investigar aumento de custo ou leituras integrais.
10. Executar e comprovar descarte autorizado.

---

## 14. Atributos de Qualidade

| Atributo | Meta inicial |
|---|---|
| Completude | 100% dos lotes elegíveis com contagem e manifesto |
| Integridade financeira | 100% das partições com soma de controle aprovada ou exceção justificada |
| Frescor incremental | Conforme domínio; sugerido até 15 minutos para eventos e até 24 horas para dados frios |
| Consulta warm | P95 inferior a 10 segundos para filtros por período e chave |
| Recuperação cold | Prazo definido por classe e testado periodicamente |
| Retomada | Reprocessar partição sem duplicar dados |
| Auditoria | 100% das execuções, acessos e expurgos registrados |
| Segurança | Zero PAN em claro e nenhum acesso fora do tenant autorizado |
| Redução DB2 | Meta definida após baseline de espaço, I/O e backup |
| Custo | Medido por armazenamento, processamento, consulta e egress |

As metas devem ser recalibradas após a PoC. Nao se deve prometer uma latência de consulta do data lake equivalente à API transacional.

### 14.1 Indicadores de sucesso

- redução mensurável do crescimento mensal do DB2;
- redução de duração e tamanho do backup;
- queda de I/O associado a consultas históricas;
- percentual de consultas históricas atendidas fora do DB2;
- custo por terabyte e por consulta;
- zero divergências financeiras sem explicação;
- tempo de recuperação de um lote histórico dentro do SLA.

---

## 15. Riscos e Mitigacoes

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Snapshot inconsistente entre tabelas | Media | Crítico | Snapshot coordenado, CDC de convergência e checks relacionais |
| Carga degrada DB2 | Alta | Alto | Extração indexada, limite de paralelismo, janela e teste de impacto |
| Data lake vira depósito sem governança | Alta | Alto | Catálogo, owner, contratos, qualidade, SLA e política de retenção |
| Small files degradam consultas | Alta | Médio | Batches adequados, compactação e monitoramento |
| CDC perde alterações | Media | Crítico | Checkpoints duráveis, retenção de log, reconciliação e replay |
| Contagem igual mas valor incorreto | Media | Crítico | Somas por moeda, amostras, hashes e consultas de reconciliação |
| Custo de consulta supera economia | Media | Alto | FinOps, views, partições, cache e limites de leitura |
| Exposição de dados pessoais | Media | Crítico | Classificação, masking, RBAC, criptografia e DLP |
| Expurgo prematuro | Baixa | Crítico | Aprovação separada, legal hold e janela de restauração |
| Dependência da ferramenta escolhida | Media | Médio | Formato aberto, Parquet, contratos e abstração de engine |
| Retorno ao DB2 por falta de funcionalidade | Media | Alto | Migrar consultas prioritárias e medir fallback |
| Alteração de schema quebra consumidores | Media | Médio | Registry, compatibilidade e coexistência de versões |
| Dados arquivados sem relação lógica | Media | Alto | Preservar chaves, metadados, foreign keys lógicas e catálogo |

---

## 16. Roadmap e Criterios de Aceite

### 16.1 Fase 1 — PoC técnica

- [ ] Inventário de duas tabelas relacionadas.
- [ ] Baseline de DB2: espaço, I/O, backup e consultas.
- [ ] Extração com predicado indexado.
- [ ] Escrita Parquet e tabela aberta.
- [ ] Manifesto, checksum e catálogo.
- [ ] Consulta SQL de referência.
- [ ] Teste de schema evolution.
- [ ] Teste de reprocessamento sem duplicidade.
- [ ] Medição de custo e performance.

**Saída**: relatório de PoC com decisão de escala.

### 16.2 Fase 2 — Histórico prioritário

- [ ] Transações encerradas e eventos relacionados.
- [ ] Arquivos e auditoria Hiker.
- [ ] Conciliação e liquidação.
- [ ] Quarantine e alertas.
- [ ] Reconciliacao financeira e referencial.
- [ ] Views para consultas históricas.
- [ ] Aprovação do primeiro expurgo controlado.

### 16.3 Fase 3 — Incremental

- [ ] CDC ou delta com watermark.
- [ ] Janela de sobreposição e deduplicação.
- [ ] Tratamento de update e delete.
- [ ] Monitoramento de atraso.
- [ ] Reconciliação diária DB2 versus lake.
- [ ] Compaction e manutenção de tabelas.

### 16.4 Fase 4 — Operação e otimização

- [ ] Políticas de ciclo de vida por domínio.
- [ ] Archive e teste de recuperação.
- [ ] Legal hold.
- [ ] FinOps e chargeback por domínio.
- [ ] Desativação gradual de snapshots redundantes.
- [ ] Runbooks e treinamento de operações.

### 16.5 Critérios de aceite

A solução pode ser considerada pronta para produção quando:

- o escopo, proprietário e retenção de cada domínio estiverem aprovados;
- a carga inicial for reconciliada por contagem, valores, chaves e amostras;
- a captura incremental atingir o watermark de convergência;
- as consultas prioritárias funcionarem sem acesso direto ao DB2;
- a retomada de partição e o reprocessamento forem testados;
- raw, manifestos e auditoria estiverem protegidos contra alteração indevida;
- acessos, exportações e expurgos estiverem auditados;
- o custo projetado estiver dentro do orçamento aprovado;
- a redução de DB2 for medida após expurgo piloto;
- exista plano de rollback e restauração excepcional.

---

## 17. Decisoes Arquiteturais (ADRs)

### ADR-001: Data lake governado como camada de repouso

**Contexto**: Snapshots do DB2 replicam volume e nao oferecem consulta histórica eficiente.

**Decisão**: Adotar object storage governado com Parquet e tabela aberta para dados históricos de baixa frequência.

**Consequências**: Menor pressão no DB2 e consulta analítica flexível; exige catálogo, qualidade e operação de plataforma.

### ADR-002: Carga inicial separada de ingestão incremental

**Contexto**: Uma carga histórica pode durar dias enquanto o DB2 continua recebendo alterações.

**Decisão**: Executar carga inicial e depois convergir por CDC ou delta com watermark e deduplicação.

**Consequências**: Evita lacunas durante a migração; aumenta a necessidade de controle de posição e reconciliação.

### ADR-003: Parquet com tabela aberta

**Contexto**: Arquivos Parquet isolados nao resolvem upsert, evolução de schema, snapshot lógico e compactação.

**Decisão**: Usar Parquet como formato físico e uma tecnologia de tabela aberta escolhida por compatibilidade do ecossistema.

**Consequências**: Melhor governança e portabilidade; exige manutenção de metadados e compactação.

### ADR-004: DB2 permanece como sistema transacional

**Contexto**: Dados históricos podem ser consultados fora do DB2, mas pagamentos correntes exigem baixa latência e consistência operacional.

**Decisão**: Manter DB2 como autoridade do hot path até decisão posterior baseada em evidência.

**Consequências**: Menor risco de migração; coexistência de camadas e necessidade de definir claramente o período de corte.

### ADR-005: Expurgo como decisão independente

**Contexto**: Copiar dados nao prova que é seguro removê-los da origem.

**Decisão**: Separar ingestão, validação, disponibilização e expurgo, com aprovação e legal hold.

**Consequências**: Processo mais seguro e auditável; redução de espaço acontece depois da validação, nao imediatamente.

### ADR-006: Retenção por domínio e classificação

**Contexto**: Transações, logs, arquivos e dados pessoais possuem necessidades diferentes.

**Decisão**: Definir ciclo de vida por entidade, finalidade, criticidade e obrigação de retenção.

**Consequências**: Melhor aderência a compliance e custo; exige catálogo e donos de dados ativos.

### ADR-007: Consulta por camada governada

**Contexto**: Acesso direto ao bucket dificulta autorização, auditoria, qualidade e estabilidade.

**Decisão**: Expor dados por views, data marts ou query service com catálogo e controle de acesso.

**Consequências**: Maior segurança e consistência de métricas; requer uma camada adicional de serving.

---

## 18. Premissas e Proximas Decisoes

### 18.1 Premissas

- O DB2 possui mecanismos de exportação ou acesso de leitura controlado.
- Existem chaves e colunas de data suficientes para particionar o histórico.
- O Gateway continuará processando dados correntes durante a migração.
- O time de dados poderá operar storage, catálogo, jobs e consultas.
- Compliance definirá retenção, legal hold e finalidade por domínio.
- A organização aceita eventualidade e maior latência para dados frios.

### 18.2 Decisões necessárias

1. Qual é a data de corte por tabela e por estado transacional?
2. O DB2 oferece CDC aprovado e qual é a retenção do log?
3. Qual mecanismo de snapshot consistente está disponível?
4. Qual engine de consulta já existe na organização?
5. Iceberg, Delta ou Hudi se integra melhor ao ambiente atual?
6. Quais tabelas devem ser migradas primeiro?
7. Quais dados precisam permanecer pesquisáveis em menos de 10 segundos?
8. Qual o prazo de recuperação para archive?
9. Quais dados possuem PAN, documentos, contas ou chaves pessoais?
10. Qual política impede expurgo quando houver investigação ou obrigação legal?
11. Qual orçamento inclui storage, consultas, egress, processamento e suporte?
12. Qual redução mínima de DB2 justifica a migração?
13. Qual equipe será dona da plataforma e de cada domínio?
14. Quais consultas históricas atuais precisam ser migradas antes do expurgo?

### 18.3 Primeiro experimento recomendado

Executar uma PoC com uma tabela de auditoria e uma tabela transacional relacionada, cobrindo:

```text
DB2 → extração consistente → raw → standardized → curated
  → consulta SQL → reconciliação → simulação de expurgo → recuperação
```

A decisão de escala deve depender dos números observados de impacto no DB2, custo, tempo de consulta, completude e esforço operacional. Estimativas de volume ou economia nao devem ser tratadas como fatos antes dessa medição.

---

## 19. Glossario

| Termo | Definicao |
|---|---|
| **Data lake** | Repositório de dados em diferentes níveis de tratamento, normalmente sobre object storage |
| **Landing** | Área inicial de recebimento de arquivos ou lotes |
| **Raw** | Dados preservados próximos da origem, sem transformação destrutiva |
| **Standardized** | Dados com tipos, nomes e metadados padronizados |
| **Curated** | Dados tratados e modelados para consumo governado |
| **Archive** | Camada de dados frios com acesso restrito e recuperação mais lenta |
| **Data lakehouse** | Arquitetura que combina storage de lake com tabelas transacionais e consulta analítica |
| **CDC** | Change Data Capture; captura de alterações na origem |
| **Watermark** | Posição ou marca que identifica até onde a ingestão foi processada |
| **Snapshot** | Representação consistente de dados em determinado momento |
| **Manifesto** | Documento que descreve lote, arquivos, contagens, checksums e origem |
| **Small files** | Excesso de arquivos pequenos que prejudica listagem e leitura analítica |
| **Compaction** | Reorganização de arquivos pequenos em arquivos maiores e mais eficientes |
| **Schema evolution** | Mudança controlada do schema ao longo do tempo |
| **Tabelas abertas** | Formato com metadados que permite snapshots, evolução e operações sobre arquivos |
| **Quarantine** | Área para dados que falharam em qualidade ou integridade |
| **Legal hold** | Bloqueio de descarte por investigação ou obrigação legal |
| **Hot data** | Dados de acesso frequente e baixa latência |
| **Warm data** | Dados consultados ocasionalmente com acesso ainda operacional |
| **Cold data** | Dados raramente acessados, priorizando custo de armazenamento |
| **Lineage** | Relação entre origem, transformação, versão e destino do dado |
| **Expurgo** | Remoção controlada e comprovada de dados conforme política |
| **Sistema de registro** | Sistema autorizado a manter o estado oficial de uma informação |
