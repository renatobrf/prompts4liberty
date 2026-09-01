# Avaliação de Arquitetura - DDD Domain-Driven Design
## Plataforma Varejo Segmentada por Domínios

**Data da Avaliação:** 2026-09-01  
**Versão:** 1.0  
**Público-alvo:** Arquitetos, Tech Leads, Product Owners

---

## 1. Resumo Executivo

Esta avaliação propõe uma reorganização da arquitetura atual para um modelo segmentado por domínios usando **Domain-Driven Design (DDD)**, permitindo que cada vertical de negócio (B2B, e-commerce, lojas físicas, logística, marketplace, crediário) operate de forma independente com autonomia operacional, enquanto mantém coesão através de fronteiras de domínio bem definidas.

### Benefícios Esperados
- **Autonomia**: Cada vertical com próprio ciclo de desenvolvimento e deploy
- **Escalabilidade**: Scaling independente por domínio
- **Resiliência**: Falhas isoladas não cascateiam
- **Time Ownership**: Squads donos do domínio, responsáveis do código ao deployment
- **Evolução Independente**: Tecnologias e padrões podem variar por contexto

---

## 2. Estado Atual vs. Proposto

### 2.1 Arquitetura Atual
```
┌─────────────────────────────────────────────────────┐
│         Monolíticos + Plataforma Emergente         │
├─────────────────────────────────────────────────────┤
│ Mainframes (COBOL/DB2) - Sistema Legado            │
│ AS/400 (i-Series) - Sistema Legado                 │
│ Linux On-Premise - Aplicações tradicionais         │
│ Kubernetes + Microserviços - Nova plataforma       │
│ Kafka (ESB/CDC) - Integração ponto-a-ponto        │
└─────────────────────────────────────────────────────┘
         ↓
    API Gateway (único ponto de acesso)
         ↓
    Front-ends (Node.js/Go) + Back-ends (Python/Java)
         ↓
    MongoDB (front) + PostgreSQL/DB2 (back)
```

**Problemas Identificados:**
- Múltiplas fontes de verdade (DB2 vs PostgreSQL vs MongoDB)
- Falta de limites claros entre domínios
- Governança de dados centralizada
- Dificuldade de evolução independente dos domínios
- Acoplamento via camada de API Gateway

### 2.2 Arquitetura Proposta (DDD)
```
┌───────────────────────────────────────────────────────────┐
│          Plataforma Segmentada por Domínios (DDD)         │
├───────────────────────────────────────────────────────────┤
│                                                            │
│  ┌─────────────┬──────────────┬──────────────┬──────┐    │
│  │ Domínio B2B │ Domínio      │ Domínio      │ ... │    │
│  │             │ E-commerce   │ Logística    │      │    │
│  │ Bounded      │ Bounded      │ Bounded      │      │    │
│  │ Context      │ Context      │ Context      │      │    │
│  └─────────────┴──────────────┴──────────────┴──────┘    │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │   Service Bus / Event Streaming (Kafka)           │    │
│  │   - Domain Events                                 │    │
│  │   - Integração Entre Contextos                   │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │   Anti-Corruption Layer / Shared Adapters        │    │
│  │   - Integração com Mainframes/AS400              │    │
│  │   - Transformação de Protocolos                  │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
│  ┌──────────────┬──────────────┬──────────────┬──────┐    │
│  │ Legacy       │ Legacy       │ Config       │ ...  │    │
│  │ Mainframe    │ AS/400       │ Server       │      │    │
│  └──────────────┴──────────────┴──────────────┴──────┘    │
└───────────────────────────────────────────────────────────┘
```

---

## 3. Domínios Identificados (Bounded Contexts)

### 3.1 Catálogo B2B (B2B Domain)
**Responsabilidade**: Gerenciar produtos, preços e ofertas para clientes business-to-business.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Produto, CatalogoPorCliente, PreçoNegociado, OfertaB2B |
| **Agregados** | Produto (raiz), Cliente B2B, Negociação |
| **Repositórios** | ProductCatalog, NegotiationStorage |
| **Linguagem Ubíqua** | "Tabela de preço", "Pedido por contrato", "Aprovação comercial" |
| **Tecnologia Sugerida** | Node.js/Go (API), PostgreSQL ou MongoDB |
| **Eventos de Domínio** | ProdutoAdicionado, PreçoAlterado, ClienteAprovado |
| **Integração Legada** | CDC do DB2 para sincronizar catálogo master |

### 3.2 E-commerce (E-commerce Domain)
**Responsabilidade**: Plataforma de varejo online para consumidores finais.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Produto, Carrinho, Pedido, Pagamento, Cliente |
| **Agregados** | Pedido (raiz), Cliente, Catálogo |
| **Repositórios** | OrderStorage, UserProfileStorage, CartStorage |
| **Linguagem Ubíqua** | "Adicionar ao carrinho", "Confirmar compra", "Rastrear pedido" |
| **Tecnologia Sugerida** | Node.js (frontend rich), Java/Python (backend) |
| **Eventos de Domínio** | PedidoCriado, PagamentoRecebido, PedidoEnviado |
| **Integração Legada** | CDC para sincronizar clientes e produtos do legado |

### 3.3 Lojas Físicas (Retail Stores Domain)
**Responsabilidade**: Operações de lojas presenciais, estoque e ponto de venda.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Loja, Estoque, Transação POS, Cliente Presencial |
| **Agregados** | Loja (raiz), Inventário |
| **Repositórios** | StoreInventory, SalesTransactionLog |
| **Linguagem Ubíqua** | "Stock-out", "Venda no balcão", "Devolução", "Nota fiscal" |
| **Tecnologia Sugerida** | Java (robustez), PostgreSQL |
| **Eventos de Domínio** | ProdutoVendido, EstoqueAtualizado, LogVendaRegistrada |
| **Integração Legada** | AS/400 como fonte de verdade para estoque, CDC bidirecional |

### 3.4 Logística (Logistics Domain)
**Responsabilidade**: Gerenciar roteiros, entregas, rastreamento e otimização de rotas.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Pedido Logístico, Rota, Entregador, Localização, SLA |
| **Agregados** | Rota (raiz), Pedido Logístico |
| **Repositórios** | RouteStorage, DeliveryEventLog |
| **Linguagem Ubíqua** | "Picking", "Packing", "Despacho", "Entregue", "RMA" |
| **Tecnologia Sugerida** | Python/Go (otimização e APIs), PostgreSQL + Redis |
| **Eventos de Domínio** | PedidoDespachado, RotaOtimizada, EntregaConcluída |
| **Integração Legada** | Kafka Connect para sincronizar com mainframe |

### 3.5 Marketplace (Marketplace Domain)
**Responsabilidade**: Plataforma que conecta múltiplos vendedores e compradores.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Vendedor, Loja do Vendedor, Produto, Transação |
| **Agregados** | VendedorLoja (raiz), Produto |
| **Repositórios** | SellerOnboardingStorage, ListingStorage |
| **Linguagem Ubíqua** | "Onboarding de vendedor", "Comissão", "Avaliação", "Liquidação" |
| **Tecnologia Sugerida** | Node.js/Go (API rápida), MongoDB (flexibilidade de schema) |
| **Eventos de Domínio** | VendedorOnboarded, ProdutoListado, ComissãoCalculada |
| **Integração Legada** | Minimal - domínio mais novo |

### 3.6 Crediário (Lending/Installments Domain)
**Responsabilidade**: Financiamento e crédito parcelado para clientes.

| Aspecto | Descrição |
|--------|-----------|
| **Entidades Core** | Contrato de Crédito, Parcela, Cliente Creditado |
| **Agregados** | ContratoDeCredito (raiz), Parcela |
| **Repositórios** | CreditContractStorage, PaymentScheduleStorage |
| **Linguagem Ubíqua** | "Análise de crédito", "Aprovação", "Parcela vencida", "Protesto" |
| **Tecnologia Sugerida** | Java (auditoria e compliance), PostgreSQL (transações ACID) |
| **Eventos de Domínio** | CreditoAprovado, ParcelaVencida, ParcelaPaga |
| **Integração Legada** | COBOL/DB2 crítico - Anti-Corruption Layer mandatório |

---

## 4. Padrões DDD Recomendados

### 4.1 Bounded Contexts
Cada domínio é um **Bounded Context** independente com:
- **Próprio modelo de dados** (não compartilhar tabelas)
- **Próprio banco de dados** (Database per Service)
- **Próprio ciclo de release**
- **Próprio repositório Git** (ou pastas bem separadas)

### 4.2 Agregados
Estrutura hierárquica de entidades com raiz agregada:

```python
# Exemplo: Agregado Pedido no E-commerce
class Pedido:  # Raiz agregada
    id: UUID
    cliente: Cliente  # Entidade
    itens: List[ItemPedido]  # Entidades
    endereco_entrega: EnderecoEntrega  # Value Object
    status: StatusPedido  # Value Object
    criado_em: datetime
    
    def adicionar_item(self, produto_id, quantidade):
        # Lógica de negócio protegida
        if self.status != StatusPedido.RASCUNHO:
            raise PedidoJaConfirmado()
        # ...
```

### 4.3 Value Objects
Objetos imutáveis que representam conceitos do domínio:

```python
# Exemplos
class Moeda(ValueObject):
    valor: Decimal
    iso_code: str  # BRL, USD

class Endereco(ValueObject):
    rua: str
    numero: str
    cep: str
    cidade: str
    estado: str
```

### 4.4 Domain Events
Eventos que representam fatos ocorridos no domínio:

```python
# Exemplo de evento
class PedidoCriado(DomainEvent):
    pedido_id: UUID
    cliente_id: UUID
    total: Moeda
    timestamp: datetime
```

### 4.5 Anti-Corruption Layer (ACL)
Camada que protege o domínio ao integrar com legado:

```python
# Adapter que traduz do legado para o domínio
class MainframeProductAdapter:
    def fetch_product(self, mainframe_sku):
        # Chama Cobol/DB2
        mainframe_product = self.mainframe_service.get_product(mainframe_sku)
        # Traduz para modelo de domínio
        return Product(
            sku=mainframe_product.SKU,
            nome=mainframe_product.NOME_PRODUTO,
            preco=Moeda(mainframe_product.PRECO, 'BRL')
        )
```

---

## 5. Comunicação Entre Domínios

### 5.1 Padrões de Integração

#### 5.1.1 Domain Events via Kafka (Recomendado)
```
Domínio E-commerce       Domínio Logística
    │                          │
    ├─ PedidoCriado ──→ Kafka ──→ Subscreve
    │                          │
    │                    ┌─ Cria Tarefa Logística
    └─ PagamentoRecebido ┘
```

**Vantagens:**
- Acoplamento temporal reduzido
- Fácil auditoria via log de eventos
- Permite replay de eventos

#### 5.1.2 REST com Circuit Breaker (Síncrono, com cuidado)
Use apenas quando necessário low-latency e com fallbacks:

```python
# Exemplo: E-commerce consulta disponibilidade em Logística
class ShippingServiceClient:
    @circuit_breaker(failure_threshold=5, recovery_timeout=60)
    def check_delivery_availability(self, order):
        try:
            return self.logistics_api.get_availability(order.endereco)
        except CircuitBreakerOpen:
            # Fallback: assume entrega em 5 dias
            return DeliveryEstimate(days=5, status='estimated')
```

#### 5.1.3 API Gateway como Orquestrador (Minimamente)
O API Gateway NÃO deve conter lógica de negócio:

```yaml
# Apenas roteamento e segurança
GET /api/v1/orders/{id}
  ↓
Autenticação + Rate Limit + Logging
  ↓
E-commerce Service: GET /orders/{id}
  ↓
Resposta ao cliente
```

### 5.2 Shared Kernel (Opcional)
Código reusável entre domínios - **use com moderação**:

```python
# library/shared_kernel/value_objects.py
class Moeda(ValueObject):
    """Value Object compartilhado entre domínios"""
    valor: Decimal
    iso_code: str

# Cada domínio importa
from shared_kernel import Moeda
```

---

## 6. Infraestrutura e Suporte Técnico

### 6.1 Banco de Dados por Domínio

| Domínio | Tipo | Banco | Justificativa |
|---------|------|-------|---------------|
| B2B | Relacional | PostgreSQL | Estrutura bem-definida, relatórios |
| E-commerce | Híbrido | PostgreSQL + MongoDB | Pedidos relacionais, catálogo flexível |
| Lojas Físicas | Relacional | PostgreSQL | Transações ACID críticas |
| Logística | Relacional + Cache | PostgreSQL + Redis | Queries otimizadas, rota em cache |
| Marketplace | NoSQL | MongoDB | Schema variável por vendedor |
| Crediário | Relacional | PostgreSQL | Auditoria e compliance rigorosos |

### 6.2 Message Broker
**Apache Kafka** (já presente)
- Tópico por domínio: `b2b-events`, `ecommerce-events`, `logistics-events`, etc.
- Retenção: 7-30 dias para replay
- Particionamento por `aggregate_id` para garantir ordem

### 6.3 CDC (Change Data Capture)
Manter sincronização com legado:

```yaml
# Kafka Connect Config
connector:
  name: mainframe-db2-cdc
  connector.class: io.confluent.connect.db2.Db2SourceConnector
  topics: mainframe-products
  mode: incrementalWithHistory
```

### 6.4 Container e Orquestração
- **Kubernetes** on-premise e cloud (já presente)
- **Namespace por domínio**:
  ```bash
  kubectl create namespace b2b-domain
  kubectl create namespace ecommerce-domain
  kubectl create namespace logistics-domain
  ```

### 6.5 Service Mesh (Opcional - Fase 2)
Considerar **Istio** ou **Linkerd** para:
- Retry automático
- Timeout enforcement
- Distributed tracing
- Mutual TLS entre serviços

---

## 7. Padrão de Desenvolvimento

### 7.1 Estrutura de Pastas (por Domínio)
```
ecommerce-domain/
├── domain/
│   ├── models/
│   │   ├── order.py
│   │   ├── customer.py
│   │   └── cart.py
│   ├── aggregates/
│   │   └── order_aggregate.py
│   ├── value_objects/
│   │   ├── money.py
│   │   └── address.py
│   ├── services/
│   │   ├── order_service.py
│   │   └── pricing_service.py
│   ├── repositories/
│   │   └── order_repository.py
│   └── events/
│       ├── order_created.py
│       ├── payment_received.py
│       └── order_shipped.py
├── application/
│   ├── services/
│   │   ├── create_order_service.py
│   │   └── confirm_payment_service.py
│   ├── dtos/
│   │   └── order_dto.py
│   └── event_handlers/
│       └── on_order_created.py
├── infrastructure/
│   ├── persistence/
│   │   └── postgres_order_repository.py
│   ├── external_services/
│   │   └── payment_gateway_adapter.py
│   └── messaging/
│       └── kafka_event_publisher.py
├── presentation/
│   └── api/
│       ├── __init__.py
│       └── routes.py
├── tests/
│   ├── unit/
│   ├── integration/
│   └── acceptance/
└── Dockerfile
```

### 7.2 Stack Recomendado por Domínio

| Domínio | Backend | Frontend | BD | Fila |
|---------|---------|----------|-----|------|
| B2B | Python (FastAPI) | Node.js React | PostgreSQL | Kafka |
| E-commerce | Java (Spring) | Node.js Next.js | PostgreSQL/MongoDB | Kafka |
| Lojas Físicas | Java (Spring) | Desktop/Mobile | PostgreSQL | Kafka |
| Logística | Python (FastAPI) + Go | React | PostgreSQL + Redis | Kafka |
| Marketplace | Node.js (Express) | React | MongoDB | Kafka |
| Crediário | Java (Spring Boot) | React | PostgreSQL | Kafka |

---

## 8. Roadmap de Implementação

### Fase 1: Foundation (Meses 1-3)
- [ ] Definir Bounded Contexts oficialmente
- [ ] Criar repositórios separados por domínio (ou namespaces)
- [ ] Implementar ACL para legado (Mainframe + AS/400)
- [ ] Configurar Kafka topics e CDC para sincronização
- [ ] Documentar Linguagem Ubíqua por domínio

### Fase 2: Autonomia (Meses 4-6)
- [ ] Implementar 2-3 agregados por domínio
- [ ] Setup de CI/CD independente por domínio
- [ ] Database per Service (migração progressiva)
- [ ] Implementar Domain Events em Kafka
- [ ] Event sourcing (piloto em 1 domínio)

### Fase 3: Escala (Meses 7-12)
- [ ] Implementar todos os agregados core
- [ ] Service Mesh (Istio) para observabilidade
- [ ] Polyglot persistence refinado
- [ ] Estratégia de cache e CQRS (se necessário)
- [ ] Disaster recovery por domínio

### Fase 4: Otimização (Contínuo)
- [ ] Performance tuning de queries
- [ ] Estratégia de sharding por domínio (se necessário)
- [ ] Saga pattern para transações distribuídas
- [ ] Chaos engineering e resiliência

---

## 9. Governança e Padrões

### 9.1 Guardrails por Domínio
```yaml
Cada domínio DEVE:
  ✓ Ter um Product Owner e Tech Lead designados
  ✓ Documentar sua Linguagem Ubíqua (glossário)
  ✓ Ter testes unitários com cobertura > 80%
  ✓ Seguir versionamento semântico de API
  ✓ Publicar Domain Events em Kafka
  
Cada domínio NÃO PODE:
  ✗ Compartilhar tabelas de banco de dados
  ✗ Fazer chamadas síncronas a outro domínio sem circuit breaker
  ✗ Acessar diretamente o banco de outro domínio
  ✗ Implementar lógica de negócio em camadas genéricas
```

### 9.2 Padrão de Versionamento de API
```
/api/v1/orders          (estável, produção)
/api/v2beta/orders      (testes, evolução)
```

### 9.3 Contrato de Dados Entre Domínios
Usar OpenAPI/AsyncAPI para documentar:
- Eventos publicados
- APIs consumidas
- Campos imutáveis vs. variáveis

---

## 10. Desafios e Mitigações

| Desafio | Risco | Mitigação |
|---------|-------|-----------|
| **Consistência Distribuída** | Dados inconsistentes entre domínios | Usar Saga pattern, eventual consistency por design |
| **Duplicação de Código** | Shared Kernel crescer desordenadamente | Code review rigoroso, versionamento de shared kernel |
| **Latência de Comunicação** | Eventos via Kafka podem atrasar | SLA de processamento por tipo de evento, cache local |
| **Complexidade Operacional** | Mais serviços = mais coisa para monitorar | Observabilidade centralizada (Prometheus + Grafana), alertas |
| **Integração com Legado** | Mainframe é monolítico e resistente | ACL bem-definida, CDC como bridge, migração progressiva |
| **Onboarding de Times** | Cada time aprende DDD do zero | Workshop inicial, pairing com arquiteto, documentação |

---

## 11. Critérios de Sucesso

- [ ] **Latência de Deploy**: <15 minutos por domínio
- [ ] **Availability**: 99.9% por domínio
- [ ] **Lead Time for Changes**: <5 dias
- [ ] **Mean Time to Recovery (MTTR)**: <1 hora
- [ ] **Cobertura de Testes**: >80% por domínio
- [ ] **Documentação**: Linguagem Ubíqua documentada, Bounded Contexts mapeados
- [ ] **Autonomia**: Cada domínio faz deploy independentemente

---

## 12. Próximos Passos

1. **Validar com Stakeholders**: Apresentar divisão de domínios a Product Owners
2. **Workshop DDD**: Treinar times nos conceitos de Bounded Contexts, Agregados, Value Objects
3. **Mapear Dependências Existentes**: Identificar atuais acoplamentos que precisam desacoplamento
4. **Proof of Concept**: Refatorar um pequeno agregado usando DDD em um domínio piloto
5. **Establishing Observability**: Configurar logging e tracing distribuído
6. **Planejar Migração do Legado**: Estratégia de progressiva substituição de Mainframe/AS400

---

## Anexo A: Glossário (Linguagem Ubíqua Preliminar)

### Varejo Geral
- **SKU**: Identificador único de produto
- **Stock-out**: Indisponibilidade de produto
- **RMA**: Return Merchandise Authorization (processo de devolução)
- **Nota Fiscal**: Documento fiscal obrigatório

### Logística
- **Picking**: Separação de itens do pedido no armazém
- **Packing**: Embalagem de itens
- **Despacho**: Envio para transportadora
- **Entregue**: Status final de conclusão

### Crediário
- **Análise de Crédito**: Avaliação de risco do cliente
- **Aprovação**: Liberação de limite
- **Parcela**: Fração do crédito a pagar
- **Protesto**: Ação legal por não pagamento

---

## Anexo B: Referências

- **Domain-Driven Design**: Eric Evans, "Domain-Driven Design" (2003)
- **Implementing DDD**: Vaughn Vernon (2013)
- **Building Microservices**: Sam Newman (2015)
- **Kafka for Architecture**: Confluent Platform Documentation
- **DDD Community**: ddd-community.org

---

**Documento preparado para:** renatobrf/prompts4liberty  
**Repositório**: https://github.com/renatobrf/prompts4liberty
