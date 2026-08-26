# Avaliação de Arquitetura: Export de Dados Legacy do DB2

## 1. Contexto & Problema

### Situação Atual
- **Database**: DB2 em crescimento exponencial após anos de operação do gateway de pagamentos
- **Escopo**: Operações transacionais de cartões (crédito, débito), boleto registrado e PIX
- **Dor**: Carga de processamento elevada, performance degradada, custos operacionais crescentes
- **Objetivo**: Exportar dados históricos a partir de uma data de corte para aliviar carga imediata

### Desafios Identificados
1. **Volume de Dados**: Histórico acumulado de transações financeiras de anos
2. **Disponibilidade**: Sistema em produção; export não pode interromper operações
3. **Integridade**: Dados financeiros sensíveis; auditoria e compliance são críticos
4. **Performance**: Queries em tabelas grandes tendem a degradar ainda mais o DB2
5. **Consistência**: Garantir snapshot consistente sem locks longos
6. **Rastreabilidade**: Auditoria completa do processo de export

---

## 2. Análise do Escopo de Dados

### Tabelas Críticas (Presumidas)
Com base na arquitetura do Hiker e no domínio de pagamentos:

| Tabela | Volume (Est.) | Natureza | Risco |
|--------|---------------|----------|-------|
| `TRANSACOES` | 100M+ registros | Fact table - transações processadas | **Alto** - núcleo do negócio |
| `ARQUIVOS_RECEBIDOS` | 1M+ registros | Remessas, retornos, extratos | Alto |
| `VALIDACOES_HIKER` | 100M+ registros | Logs de validação estrutural/financeira | Médio |
| `AUDITORIA_EVENTOS` | 500M+ registros | Eventos de pipeline (bulk files) | Médio |
| `RECONCILIACAO` | 50M+ registros | Matching parceiro/BACEN | Alto |
| `ERROS_PROCESSAMENTO` | 10M+ registros | Logs de falhas de carga | Médio |

**Estimativa Total**: ~750M+ registros (escala petabyte-range em DB2)

### Dependências de Integridade Referencial
```
TRANSACOES ──┬── ARQUIVOS_RECEBIDOS
             ├── VALIDACOES_HIKER
             ├── RECONCILIACAO
             └── AUDITORIA_EVENTOS
```

---

## 3. Opções Arquiteturais

### Opção A: Export Direto com DB2 Unload

#### Descrição
Usar utilitários nativos de DB2 (`UNLOAD`, `EXPORT`) para extrair dados diretamente para arquivos (CSV, Parquet, ou binário).

#### Arquitetura
```
┌─────────────────────┐
│   DB2 (Produção)    │
│  [Tabelas Legacy]   │
└──────────┬──────────┘
           │
           ├─ [WHERE data_criacao < '2024-01-01']
           │
           ▼
┌──────────────────────────┐
│  DB2 UNLOAD/EXPORT       │
│  (Particionado por data) │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Arquivos S3/Objeto      │
│  (Parquet + Manifest)    │
└──────────────────────────┘
```

#### Pros
- ✅ Nativo do DB2, otimizado para performance
- ✅ Paralelizável (UNLOAD com `PARALLELISM=n`)
- ✅ Baixa latência (sem passagem por aplicação)
- ✅ Controle fino de encoding, delimitadores

#### Contras
- ❌ Requer acesso direto ao DB2 (credenciais, firewall)
- ❌ Sem validação semântica durante export
- ❌ Dificuldade em rastrear progresso em tempo real
- ❌ Risco de deadlock se queries longas concorrerem com operações normais

#### Recomendação
**Viável para fase 1 — export bulk inicial**. Implementar janela de manutenção (ex: 22h-06h) para minimizar impacto.

---

### Opção B: Export via Pipeline ETL (Kafka + Hiker)

#### Descrição
Estender o Hiker para atuar como **consumer de dados legados**. Usar um job ETL que:
1. Lê dados do DB2 em mini-batches
2. Passa pelo Hiker (validação, contexto, eventos)
3. Publica para Kafka
4. Consome de Kafka → S3 (Data Lake)

#### Arquitetura
```
┌─────────────────────┐
│   DB2 (Produção)    │
│  [Mini-batch read]  │
└──────────┬──────────┘
           │ (Cursor + Offset)
           ▼
┌──────────────────────────┐
│  ETL Job (Python/Spark)  │
│  [Batch size: 10K recs]  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Hiker (Legacy Mode)     │
│  - Validação            │
│  - Acumulação de contexto│
│  - Emissão de eventos   │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Kafka (Topic: legacy)   │
│  [Partições = P/F]       │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  S3 Data Lake            │
│  (Particionado por data) │
│  Formato: Parquet        │
└──────────────────────────┘
           │
           ▼
┌──────────────────────────┐
│  Dashboard (Auditoria)   │
│  - Progresso            │
│  - Validações           │
│  - Erros               │
└──────────────────────────┘
```

#### Pros
- ✅ Reutiliza componente Hiker (coerência arquitetural)
- ✅ Validação semântica durante export
- ✅ Rastreabilidade completa (eventos de auditoria)
- ✅ Resiliência com Kafka (retry, dead-letter)
- ✅ Observabilidade em tempo real
- ✅ Separação de concerns (read, validate, publish, persist)

#### Contras
- ❌ Overhead de aplicação (mais lento que DB2 nativo)
- ❌ Maior complexidade operacional
- ❌ Requer infra Kafka escalável
- ❌ Curva de aprendizado (Python/Spark + Hiker extensão)

#### Recomendação
**Recomendado para fase 2 — export contínuo e governança**. Melhor para compliance e auditoria.

---

### Opção C: Hybrid (DB2 Unload + Data Lake + Hiker Validation)

#### Descrição
Combinar força de DB2 nativo (export rápido) com Hiker (validação em camadas):
1. **Fase 1**: DB2 UNLOAD → S3 (raw)
2. **Fase 2**: Job ETL lê de S3, passa por Hiker, valida
3. **Fase 3**: Publica dados validados → S3 (curated) + eventos → Kafka

#### Arquitetura
```
┌──────────────────────┐
│   DB2 (Native UNLOAD)│
└──────────┬───────────┘
           │ (Rápido, bulk)
           ▼
┌──────────────────────┐
│  S3 Raw Layer        │
│  (Parquet comprimido)│
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────┐
│  Hiker Validation Job        │
│  (Read S3 → Validate)        │
│  [Passo 2,3,4 do Hiker]      │
└──────────┬───────────────────┘
           │
           ├─ ✅ Válidos
           │   ▼
           │  S3 Curated Layer
           │
           └─ ❌ Inválidos
               ▼
              Dead Letter Queue
```

#### Pros
- ✅ Performance máxima (DB2 nativo para leitura)
- ✅ Validação robusta (Hiker)
- ✅ Resiliência (stages separadas)
- ✅ Observabilidade (eventos Hiker)
- ✅ Escalabilidade (Job paralelo sobre S3)

#### Contras
- ❌ Complexidade moderada (múltiplas stages)
- ❌ Custo de armazenamento (raw + curated)
- ❌ Necessidade de orquestração (Airflow/Step Functions)

#### Recomendação
**Best practice — abordagem recomendada**. Melhor trade-off entre performance, confiabilidade e governança.

---

## 4. Arquitetura Recomendada: Hybrid (Opção C)

### Fluxo Detalhado

```
DATA DE CORTE: 2024-01-01
│
├─ [SEMANA 1] ─────────────────────────────────────────
│  └─ DB2 UNLOAD (Batch 1: 2023-01-01 ~ 2023-06-30)
│     → S3://legacy-export/raw/batch-1/
│
├─ [SEMANA 2] ─────────────────────────────────────────
│  ├─ Hiker Validation (Batch 1)
│  │  → Eventos de auditoria
│  │  → S3://legacy-export/curated/batch-1/ (✅ válidos)
│  │  → DLQ (❌ inválidos)
│  │
│  └─ DB2 UNLOAD (Batch 2: 2023-07-01 ~ 2023-12-31)
│     → S3://legacy-export/raw/batch-2/
│
├─ [SEMANA 3] ─────────────────────────────────────────
│  ├─ Hiker Validation (Batch 2)
│  └─ [Em paralelo] DB2 UNLOAD (Batch 3, se houver)
│
├─ [SEMANA N+1] ────────────────────────────────────────
│  └─ Verificação de integridade + Assinatura digital
│     → Arquivo manifest + checksums
```

### Componentes Técnicos

#### 4.1 DB2 UNLOAD Job
```bash
# Script: export-db2-unload.sh
#!/bin/bash

DATE_CUTOFF="2024-01-01"
BATCH_ID="batch-$(date +%Y%m%d-%H%M%S)"
S3_PATH="s3://legacy-export/raw/${BATCH_ID}/"

db2 <<EOF
CONNECT TO PRODUCTION;

UNLOAD
  SELECT
    transacao_id,
    parceiro,
    tipo_operacao,
    valor,
    data_criacao,
    hash_auditoria
  FROM TRANSACOES
  WHERE data_criacao < CAST('${DATE_CUTOFF}' AS DATE)
  WITH UR
  TO PARQUET("${S3_PATH}/transacoes.parquet")
  LOBSINFILE
  MODIFIED BY COLDEL(0x01) CHARDEL(0x00) PARALLELISM=8
;

-- Repetir para ARQUIVOS_RECEBIDOS, VALIDACOES_HIKER, etc.

CONNECT RESET;
EOF

# Gerar manifest
echo "batch_id: ${BATCH_ID}" > manifest.yaml
echo "exported_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> manifest.yaml
echo "record_count: $(aws s3 ls ${S3_PATH} --recursive | wc -l)" >> manifest.yaml
aws s3 cp manifest.yaml ${S3_PATH}manifest.yaml
```

#### 4.2 Hiker Legacy Validation Job (Python)
```python
# hiker_legacy_export.py
import sys
from datetime import datetime
from pyspark.sql import SparkSession
from hiker import Hiker, HikerContext

spark = SparkSession.builder \
    .appName("hiker-legacy-export") \
    .getOrCreate()

# Ler dados brutos do S3
s3_raw_path = "s3://legacy-export/raw/batch-001/"
df = spark.read.parquet(f"{s3_raw_path}/transacoes.parquet")

# Inicializar Hiker em modo legacy
hiker = Hiker(mode="legacy_validation")

# Processar em mini-batches
batch_size = 10000
total_records = df.count()
valid_records = 0
rejected_records = 0

for idx in range(0, total_records, batch_size):
    batch = df.limit(batch_size).skip(idx)
    
    for row in batch.collect():
        ctx = HikerContext(
            arquivoId="legacy-export",
            parceiro=row['parceiro'],
            layout="DB2_LEGACY",
            timestamp=datetime.now()
        )
        
        # Passo 2: Validação estrutural
        ctx = hiker.passo(segmento=row, contexto=ctx, step=2)
        
        # Passo 3: Validação financeira
        ctx = hiker.passo(segmento=row, contexto=ctx, step=3)
        
        # Passo 4: Decisão de carga
        resultado = hiker.finalizar(contexto=ctx)
        
        if resultado.status == "aprovado":
            valid_records += 1
            # Escrever em curated
        else:
            rejected_records += 1
            # Escrever em DLQ
        
        # Emitir evento de auditoria
        hiker.emit_event(ctx)

# Escrever sumário
summary = {
    "batch_id": "batch-001",
    "total_records": total_records,
    "valid_records": valid_records,
    "rejected_records": rejected_records,
    "rejection_rate": rejected_records / total_records * 100,
    "exported_at": datetime.now().isoformat()
}

spark.createDataFrame([summary]).write.json(f"{s3_raw_path}../curated/summary.json", mode="overwrite")
```

#### 4.3 Orquestração (AWS Step Functions / Airflow)
```yaml
# airflow_dag.yaml
name: legacy-export-pipeline
schedule: "0 22 * * MON"  # Toda segunda à 22h

stages:
  - stage: db2-unload
    task: export_db2_unload
    parallelism: 1  # Executar sequencialmente para não sobrecarregar DB2
    timeout: 14400s  # 4h
    on_failure: alert-ops
    
  - stage: hiker-validation
    task: validate_with_hiker
    depends_on: db2-unload
    parallelism: 4  # 4 workers em paralelo
    timeout: 43200s  # 12h
    on_failure: alert-data-quality
    
  - stage: integrity-check
    task: verify_checksums
    depends_on: hiker-validation
    timeout: 3600s
    on_failure: quarantine-batch
    
  - stage: notify-stakeholders
    task: send_report
    depends_on: integrity-check
    recipients:
      - data-eng@company.com
      - audit@company.com
```

---

## 5. Padrão de Particionamento

### Estratégia Recomendada
```
s3://legacy-export/
├── raw/
│   ├── batch-001/
│   │   ├── transacoes.parquet
│   │   ├── arquivos_recebidos.parquet
│   │   ├── validacoes_hiker.parquet
│   │   ├── auditoria_eventos.parquet
│   │   └── manifest.yaml
│   └── batch-002/
│
├── curated/
│   ├── batch-001/
│   │   ├── transacoes/
│   │   │   └── year=2023/month=06/day=30/
│   │   │       ├── part-0001.parquet
│   │   │       └── part-0002.parquet
│   │   ├── arquivos_recebidos/
│   │   └── summary.json
│   └── batch-002/
│
└── metadata/
    ├── export-manifest.json
    ├── checksum-registry.csv
    └── audit-log.jsonl
```

### Formato de Arquivo
- **Compressão**: Snappy (balanceamento entre compressão e velocidade)
- **Tipo**: Parquet (schema-aware, suporta tipos DB2, otimizado para analytics)
- **Row Group Size**: 128 MB (padrão, adequado para leitura em cadeia)

---

## 6. Considerações de Compliance & Auditoria

### Integridade de Dados
```
┌─────────────────────────────┐
│  DB2 Source                 │
│  SELECT COUNT(*) FROM TAB   │ → 100,000,000 registros
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Arquivo Parquet (S3)       │
│  df.count() == 100,000,000  │ ✅ Validar
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Hiker Validation           │
│  valid: 99,500,000          │
│  rejected: 500,000 (audit)  │ 📋 Rastrear rejeitados
└─────────────────────────────┘
```

### Assinatura Digital
```bash
# Gerar SHA-256 de cada arquivo
sha256sum batch-001/transacoes.parquet > batch-001/transacoes.parquet.sha256

# Assinar manifest com chave privada
openssl dgst -sha256 -sign private_key.pem manifest.yaml > manifest.yaml.sig

# Verificação posteriormente
openssl dgst -sha256 -verify public_key.pem -signature manifest.yaml.sig manifest.yaml
```

### Rastreamento de Auditoria
```json
{
  "export_id": "exp-20240801-001",
  "initiated_by": "data-eng@company.com",
  "started_at": "2024-08-01T22:00:00Z",
  "completed_at": "2024-08-02T10:15:30Z",
  "batch_count": 5,
  "total_records_exported": 750000000,
  "total_records_validated": 745000000,
  "rejection_rate": 0.67,
  "s3_location": "s3://legacy-export/curated/",
  "checksum_registry": "s3://legacy-export/metadata/checksum-registry.csv",
  "compliance_notes": "Conforme BACEN 4454/2023",
  "signed_by": "automation@company.com",
  "signature": "sha256=abc123..."
}
```

---

## 7. Roadmap de Implementação

### Fase 1: PoC (4 semanas)
- [ ] Configurar acesso DB2 + S3
- [ ] Implementar DB2 UNLOAD para 1 tabela pequena (ex: ERROS_PROCESSAMENTO)
- [ ] Validar formato Parquet + checksum
- [ ] Estimar volume final baseado em amostra

**Entregável**: `legacy-export-poc.md` + Arquivos de amostra em S3

### Fase 2: Integração Hiker (4 semanas)
- [ ] Estender Hiker com modo `legacy_validation`
- [ ] Implementar ETL job (Python/Spark)
- [ ] Configurar Kafka topic para eventos
- [ ] Dashboard de progresso

**Entregável**: Pipeline completo de 1 tabela de médio porte

### Fase 3: Produção Full (6 semanas)
- [ ] Estender para todas as 6 tabelas críticas
- [ ] Testes de carga (volume simulado)
- [ ] Runbook de operação + playbooks de erro
- [ ] Treinamento de SREs

**Entregável**: Export de 750M registros em produção

### Fase 4: Otimização & Arquivamento (Contínuo)
- [ ] Análise de performance (query optimization)
- [ ] Implementar incremental export (delta)
- [ ] Disaster recovery (backup de backup)
- [ ] Descontinuação de dados de DB2 (após confirmação)

---

## 8. Riscos & Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|--------|-----------|
| **Degradação de performance do DB2** | Alta | Alto | • Executar UNLOAD em janela manutencao (22h-06h)<br>• Usar `WITH UR` (uncommitted read)<br>• Limitar paralelismo (PARALLELISM=4) |
| **Perda de dados durante export** | Baixa | Crítico | • Duplicar checksums para cada batch<br>• Comparar COUNT(*) antes/depois<br>• Manter DB2 original por 30 dias pós-export |
| **Falha de validação Hiker** | Média | Alto | • Dead Letter Queue para rejeitados<br>• Análise pós-export de padrões de erro<br>• Escalação manual para 500K+ rejeitados |
| **Custo de armazenamento (raw+curated)** | Alta | Médio | • Excluir `raw/` após validação bem-sucedida<br>• Usar lifecycle policies (S3 → Glacier após 90d)<br>• Estimar: 3TB raw → 2.5TB curated |
| **Indisponibilidade temporária de Kafka** | Baixa | Médio | • Implementar circuit breaker em Hiker<br>• Buffer local em job ETL<br>• Retry com backoff exponencial |
| **Insugestão de compliance (BACEN)** | Baixa | Crítico | • Revisar layout com compliance antes de PoC<br>• Manter auditoria granular de rejeitados<br>• Assinatura digital de export final |

---

## 9. Estimativas de Recursos

### Infraestrutura Cloud (AWS)
```
Componente                    | Custo Mensal (Est.)
──────────────────────────────┼────────────────────
DB2 (on-prem, sem delta)      | $0 (existente)
S3 (raw + curated, 7.5TB)     | $170 (~$0.023/GB/month)
EC2 (Spark cluster, 4x r5.2x) | $600 (durante export)
Kafka (MSK, 3 brokers)        | $300 (contínuo)
Data Transfer (egress)        | $50-200 (variável)
──────────────────────────────┴────────────────────
Total (Pós-export)            | ~$300-500/month
```

### Equipe (Estimado)
- **Data Engineer** (lead): 8 semanas
- **DB2 DBA**: 3 semanas (PoC + tuning)
- **DevOps**: 4 semanas (infra + monitoring)
- **QA/Compliance**: 6 semanas (testes + auditoria)

**Esforço Total**: ~21 semanas-pessoa (~5 meses, 1 squad)

---

## 10. Sucesso: Critérios de Aceitação

- ✅ 100% de registros exportados com integridade verificada
- ✅ Taxa de rejeição < 1% (ou justificada por compliance)
- ✅ Tempo total de export < 7 dias
- ✅ RTO (Recovery Time Objective): < 4h em caso de falha
- ✅ Auditoria completa rastreável (todos os eventos em Kafka/S3)
- ✅ Performance de DB2 retorna ao baseline pré-export
- ✅ Zero violações de compliance (BACEN 4454/2023)
- ✅ Documentação operacional + runbook de suporte

---

## 11. Alternativa Futura: Incremental Export

Após PoC bem-sucedido, considerar:

### CDC (Change Data Capture)
```
DB2 ─ [LogMiner / Replication] ─> Kafka ─> S3 (parquet)
```

Permite export contínuo de novos dados sem re-processar histórico.

### Benefício
- Reduz export semanal de 750M para ~5M registros/semana
- Mantém Data Lake sincronizado com DB2
- Prepara migração futura para NoSQL/Columnar (Cassandra/BigQuery)

---

## Conclusão

A **arquitetura híbrida (Opção C)** oferece o melhor balance entre:
- 🚀 **Performance** (DB2 nativo)
- 🔒 **Confiabilidade** (Hiker validation + DLQ)
- 📊 **Observabilidade** (eventos de auditoria)
- 📋 **Compliance** (rastreamento completo)

Recomenda-se iniciar com **PoC de 4 semanas** em 1 tabela menor (ERROS_PROCESSAMENTO) para validar abordagem antes de roll-out completo.

---

**Documento revisado em**: 2024-08-25  
**Versão**: 1.0  
**Status**: Pronto para discussão arquitetural
