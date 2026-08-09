# Budget Plan: Seguro Simples AWS Cloud

## Projeto
- **Serviço:** Seguro simples + anti-fraude
- **Cloud:** Amazon Web Services (`us-east-1`)
- **Tipo de compromisso:** Reserva anual / Savings Plan
- **Escopo:** produção com infraestrutura principal e serviços de suporte
- **Data:** 2026

> ⚠️ Esta estimativa é ilustrativa. Valide preços atualizados no AWS Pricing Calculator antes da compra.

---

## 1. Resumo executivo

| Item | Valor estimado |
|---|---|
| **Custo anual sem reserva** | ~$2.850 |
| **Custo anual com reserva / Savings Plan** | **~$1.980** |
| **Economia anual estimada** | **~$870** |
| **Custo mensal médio reservado** | **~$165** |
| **Compromisso anual total (sem upfront)** | $0 upfront, pago mensalmente |

---

## 2. Compra de reservas e Savings Plans

### 2.1 Compute Savings Plan para ECS Fargate

| Campo | Valor |
|---|---|
| Produto | Compute Savings Plan |
| Termo | 1 ano |
| Pagamento | No Upfront |
| Compromisso horário | ~ $0.085/h |
| Compromisso mensal | ~ $62 |
| Compromisso anual | ~ $744 |
| Cobertura | todas as tasks ECS Fargate em `us-east-1` |
| Economia estimada | ~ 35% |

**Cobertura típica:**
- `service-apolice` (0.5 vCPU / 1 GB) × 2
- `service-sinistro` (0.5 vCPU / 1 GB) × 2
- `service-premio` (0.25 vCPU / 0.5 GB) × 1
- `service-antifraude` (0.5 vCPU / 1 GB) × 1

### 2.2 RDS Reserved Instance para PostgreSQL

| Campo | Valor |
|---|---|
| Produto | Amazon RDS Reserved DB Instance |
| Engine | PostgreSQL |
| Classe | `db.t3.medium` ou `db.t4g.medium` |
| Multi-AZ | Sim |
| Termo | 1 ano |
| Pagamento | No Upfront |
| Custo mensal estimado | ~ $45 |
| Custo anual estimado | ~ $540 |
| Economia estimada | ~ 35% |

### 2.3 (Opcional) ElastiCache Reserved Node

| Campo | Valor |
|---|---|
| Produto | Amazon ElastiCache Reserved Node |
| Engine | Redis |
| Tipo | `cache.t3.micro` |
| Quantidade | 2 (primary + replica) |
| Termo | 1 ano |
| Pagamento | No Upfront |
| Custo anual estimado | ~ $380 |
| Economia estimada | ~ 35% |

> Nota: A reserva de Redis é recomendada se você usar cache ou armazenamento temporário de sessão no serviço de seguros.

---

## 3. Serviços Pay-as-you-go (sem reserva)

| Serviço | Modelo | Mensal | Anual |
|---|---|---|---|
| Amazon API Gateway (HTTP API) | pay-as-you-go | $5 | $60 |
| Amazon S3 + CloudFront | pay-as-you-go | $6 | $72 |
| Amazon ECR | pay-as-you-go | $1 | $12 |
| Amazon SQS + SNS | pay-as-you-go | $3 | $36 |
| AWS Secrets Manager | pay-as-you-go | $5 | $60 |
| Amazon Route 53 | pay-as-you-go | $3 | $36 |
| AWS Certificate Manager | gratuito | $0 | $0 |
| CloudWatch Logs + Metrics | pay-as-you-go | $12 | $144 |
| AWS X-Ray | pay-as-you-go | $3 | $36 |
| Data Transfer Out | pay-as-you-go | $5 | $60 |
| Contingência | buffer | $10 | $120 |
| **Subtotal pay-as-you-go** | | **$53** | **$636** |

---

## 4. Orçamento anual total

| Categoria | Mensal | Anual |
|---|---|---|
| ECS Fargate (Savings Plan) | $62 | $744 |
| Amazon RDS PostgreSQL (Reserved) | $45 | $540 |
| Amazon ElastiCache Redis (Reserved, opcional) | $32 | $384 |
| Serviços pay-as-you-go | $53 | $636 |
| **Total estimado** | **$192** | **$2.304** |

> Observação: se não usar ElastiCache, o total anual reservado cai para cerca de **$1.920**.

---

## 5. Recomendações de compra

1. **Validar uso real** nos primeiros 2 meses antes de comprometer reservas.
2. **Comprar Compute Savings Plan** em seguida, após confirmar baseline de uso do ECS.
3. **Comprar RDS Reserved Instance** quando o tamanho e a necessidade de Multi-AZ estiverem definidos.
4. **Avaliar ElastiCache** somente se o caching for usado em produção.
5. **Manter monitoramento de custos** com AWS Cost Explorer e alertas de orçamento.

---

## 6. Cronograma sugerido

- Meses 1-2: operar on-demand e confirmar sizing
- Mês 3: comprar Compute Savings Plan
- Mês 4: comprar RDS Reserved Instance
- Mês 6: rever uso e considerar ElastiCache reservado
- Mês 12: avaliar renovação com base em uso e crescimento

---

## 7. Pontos de atenção

- Estimativa baseada em preços de referência; taxas reais podem variar.
- RDS Multi-AZ aumenta disponibilidade, mas custa mais.
- Se a carga do ECS variar muito, use recursos de autoscaling e revise o compromisso do Savings Plan.
- Use o AWS Pricing Calculator para ajustar a reserva ao perfil de uso de `vCPU` e `RAM`.
- A reserva anual não cobre serviços pay-as-you-go, que continuam variando conforme consumo.
