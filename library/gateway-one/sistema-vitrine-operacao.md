# Documento de Arquitetura de Software
## Sistema Vitrine de Operação — Observabilidade e Inteligência para Pagamentos

| Atributo | Valor |
|---|---|
| Versão | 1.0 |
| Status | Proposta para validação |
| Domínio | Operação financeira, pagamentos e Business Intelligence |
| Papel | Produto complementar e independente do Gateway de Pagamentos |
| Público | Clientes operadores, gestores, áreas financeiras, risco e time comercial |
| Referências | `gateway-pagamentos-arquitetura-software.md` · `arq-hybrid-cloud-modern-plan.md` |
| Premissa principal | A vitrine é somente leitura sobre o core transacional |

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Oportunidade de Produto](#2-oportunidade-de-produto)
3. [Escopo e Objetivos](#3-escopo-e-objetivos)
4. [Personas e Experiência](#4-personas-e-experiência)
5. [Visão Arquitetural](#5-visão-arquitetural)
6. [Componentes Principais](#6-componentes-principais)
7. [Plataforma de Dados e BI](#7-plataforma-de-dados-e-bi)
8. [Indicadores e Painéis](#8-indicadores-e-painéis)
9. [Alertas e Inteligência Operacional](#9-alertas-e-inteligência-operacional)
10. [Fluxos de Negócio](#10-fluxos-de-negócio)
11. [Segurança, Governança e Multi-tenancy](#11-segurança-governança-e-multi-tenancy)
12. [Atributos de Qualidade](#12-atributos-de-qualidade)
13. [Integrações e Contratos](#13-integrações-e-contratos)
14. [Roadmap de Produto](#14-roadmap-de-produto)
15. [Decisões Arquiteturais (ADRs)](#15-decisões-arquiteturais-adrs)
16. [Roteiro de Demonstração Comercial](#16-roteiro-de-demonstração-comercial)
17. [Premissas e Próximas Decisões](#17-premissas-e-próximas-decisões)
18. [Glossário](#18-glossário)

---

## 1. Visão Geral

O **Sistema Vitrine de Operação** é um produto de experiência, observabilidade e inteligência operacional construído em paralelo ao Gateway de Pagamentos. Ele transforma os dados do processamento de pagamentos em uma visão clara da operação do cliente: volume, valor, conversão, falhas, liquidação, conciliação, risco e desempenho dos parceiros.

A solução não autoriza transações, não altera o estado financeiro do Gateway e não substitui o sistema transacional. Seu propósito é permitir que diferentes públicos entendam rapidamente **o que está acontecendo, por que está acontecendo e onde agir**.

A proposta combina:

- dashboard executivo para acompanhamento de negócio;
- cockpit operacional para investigação em tempo quase real;
- análises de pagamentos, liquidação e conciliação;
- alertas orientados a impacto e prioridade;
- relatórios exportáveis e compartilháveis;
- camada de dados pronta para ferramentas de BI;
- experiência de produto que pode ser apresentada como diferencial comercial.

### 1.1 Proposta de valor

> **Uma visão única da operação de pagamentos do cliente, com contexto financeiro e operacional suficiente para transformar eventos em decisões.**

### 1.2 Princípio de segurança funcional

A vitrine deve ser **read-only por padrão**. Ações que alterem transações, arquivos ou liquidações continuam sendo executadas no Gateway, em seus serviços oficiais, com autorização, idempotência e auditoria próprias. A vitrine pode oferecer atalhos de navegação ou abertura de chamados, mas não deve criar um segundo caminho transacional.

### 1.3 Diagrama de contexto

```text
┌──────────────────────────────┐
│       Usuários do cliente    │
│ Executivo · Operador · CFO   │
│ Financeiro · Risco · Auditor │
└──────────────┬───────────────┘
               │ HTTPS / SSO
               ▼
┌──────────────────────────────────────────────────────────┐
│                SISTEMA VITRINE DE OPERAÇÃO                │
│                                                          │
│  Portal Web · APIs de consulta · Alertas · Relatórios    │
│  Camada semântica · Data Mart · Catálogo de métricas     │
└────────────────────────┬─────────────────────────────────┘
                         │ leitura controlada
                         ▼
┌──────────────────────────────────────────────────────────┐
│              Plataforma de dados da vitrine              │
│ Eventos · CDC · ETL/ELT · Lakehouse · Data Warehouse     │
└────────────────────────┬─────────────────────────────────┘
                         │ contratos versionados
                         ▼
┌──────────────────────────────────────────────────────────┐
│             Gateway de Pagamentos / fontes               │
│ fato_transacao · transacao_evento · hiker_auditoria      │
│ arquivo_financeiro · liquidacao · conciliação · parceiro  │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Oportunidade de Produto

O Gateway resolve o processamento financeiro, mas o cliente frequentemente precisa de uma camada diferente para responder perguntas de gestão e operação:

- Quanto processamos hoje, por canal, parceiro e meio de pagamento?
- Qual etapa está causando perda de conversão ou atraso?
- Quais arquivos estão parados, rejeitados ou aguardando revisão?
- O valor autorizado está chegando à liquidação e à conciliação?
- Existe uma degradação concentrada em um adquirente, banco ou região?
- Quais ocorrências exigem ação agora?

A vitrine empacota essas respostas em um produto demonstrável. Isso cria uma narrativa comercial concreta: o cliente não compra apenas processamento, compra também **visibilidade, controle e capacidade de decisão**.

### 2.1 Diferenciais comercializáveis

| Diferencial | Resultado percebido pelo cliente |
|---|---|
| Visão executiva e operacional no mesmo produto | Alinha decisão estratégica e ação do time |
| Linha do tempo ponta a ponta | Explica a jornada de uma transação ou arquivo |
| Indicadores financeiros e técnicos relacionados | Conecta disponibilidade a impacto monetário |
| Alertas com contexto | Reduz o tempo entre falha e diagnóstico |
| Benchmark configurável | Permite acompanhar evolução sem expor dados de terceiros |
| Relatórios com identidade do cliente | Facilita prestação de contas e reuniões executivas |
| Arquitetura independente do core | Evolui a experiência sem aumentar o risco transacional |
| BI incorporado e exportável | Atende consumo no portal e análises corporativas |

### 2.2 Posicionamento recomendado

A solução deve ser apresentada como **Operational Intelligence para pagamentos**, e não apenas como um dashboard. Dashboard é a interface; o produto é a combinação de dados confiáveis, indicadores, contexto, alertas, investigação e governança.

---

## 3. Escopo e Objetivos

### 3.1 Objetivos de negócio

| # | Objetivo |
|---|---|
| O1 | Criar uma experiência de produto visível e demonstrável para apoiar vendas e expansão de contratos |
| O2 | Dar ao cliente autonomia para acompanhar sua operação sem depender de consultas manuais ao suporte |
| O3 | Reduzir tempo de detecção, diagnóstico e comunicação de incidentes financeiros |
| O4 | Unificar visão de transações, arquivos, liquidação, conciliação e risco |
| O5 | Disponibilizar uma base governada para BI, relatórios e análises futuras |
| O6 | Preservar isolamento, segurança e desempenho do Gateway transacional |

### 3.2 Escopo inicial

- Portal web responsivo para usuários autenticados.
- Dashboard executivo com filtros por período, parceiro, canal e meio de pagamento.
- Cockpit operacional de transações e arquivos.
- Detalhe de transação com linha do tempo de eventos.
- Monitoramento de liquidação e conciliação.
- Alertas configuráveis e central de notificações.
- Exportação de dados conforme permissão do usuário.
- APIs de consulta para integrações do cliente.
- Camada semântica com definição oficial dos indicadores.
- Data mart analítico separado do banco transacional.

### 3.3 Fora do escopo inicial

- Autorização, captura, estorno ou alteração direta de transações.
- Substituição do Hiker, Bulk Files Pipeline ou `configServerFiles`.
- Motor antifraude proprietário.
- BI corporativo completo para domínios não relacionados a pagamentos.
- Exposição de PAN ou qualquer dado sensível de cartão em claro.
- Benchmark público entre clientes identificáveis.
- Decisões automáticas de crédito, bloqueio ou liquidação.

---

## 4. Personas e Experiência

### 4.1 Personas

| Persona | Pergunta principal | Experiência prioritária |
|---|---|---|
| Executivo / sponsor | O negócio está saudável? | Scorecard, tendência, valor processado, incidentes críticos |
| Gestor de operações | Onde preciso agir agora? | Fila operacional, alertas, SLA, drill-down |
| Financeiro | O dinheiro foi liquidado e conciliado? | Fluxo autorizado-liquidado-conciliado, diferenças e aging |
| Risco / compliance | O que exige investigação? | Retenções, trilha de auditoria, evidências e exportação controlada |
| Atendimento / suporte | O que aconteceu com esta transação? | Busca por NSU, E2E, nosso número e linha do tempo |
| Administrador do cliente | Quem pode ver o quê? | Usuários, papéis, escopos e preferências de alerta |
| Vendas / pré-vendas | Como demonstro valor rapidamente? | Tenant demonstrativo, dados sintéticos e roteiro guiado |

### 4.2 Princípios de experiência

1. **Começar pelo impacto**: valor financeiro, quantidade afetada e severidade aparecem antes do detalhe técnico.
2. **Permitir investigação progressiva**: resumo, dimensão, transação e evento devem ser acessíveis em poucos passos.
3. **Mostrar o período e o escopo sempre**: nenhum número deve aparecer sem indicar filtros, atualização e qualidade dos dados.
4. **Separar fato de recomendação**: o produto deve distinguir dado observado, regra de alerta e sugestão analítica.
5. **Tratar ausência de dados como estado explícito**: `sem dados`, `atrasado` e `zero` não são a mesma coisa.

### 4.3 Navegação proposta

```text
Visão geral
├── Operação em tempo quase real
├── Transações
│   └── Detalhe e linha do tempo
├── Arquivos e Hiker
├── Liquidação e conciliação
├── Risco e compliance
├── Alertas e incidentes
├── Relatórios
└── Administração
```

---

## 5. Visão Arquitetural

### 5.1 Estilo arquitetural

A solução adota uma arquitetura **analytics-first, orientada a eventos e desacoplada do sistema transacional**:

- eventos e CDC alimentam a plataforma analítica;
- dados brutos são preservados para reprocessamento e auditoria;
- transformações produzem fatos e dimensões governados;
- uma camada semântica publica métricas consistentes para o portal e ferramentas de BI;
- o portal consulta modelos de leitura e agregações, nunca o banco transacional em consultas analíticas pesadas.

### 5.2 Arquitetura lógica

```text
┌──────────────────────────────────────────────────────────────┐
│ Experiência                                                   │
│ Portal Web · BI Embedded · APIs de consulta · Exportações    │
└─────────────────────────────┬────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Produto                                                       │
│ BFF · autorização · filtros · alertas · preferências         │
│ catálogo de métricas · relatórios · links de investigação    │
└─────────────────────────────┬────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Camada semântica e serving                                   │
│ Métricas certificadas · agregações · cache · RLS             │
│ Query service operacional · modelo para BI                   │
└─────────────────────────────┬────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Plataforma de dados                                          │
│ Ingestão · event bus · CDC · ETL/ELT · qualidade · catálogo  │
│ Data lake/object storage · warehouse/lakehouse                │
└─────────────────────────────┬────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Fontes                                                        │
│ Gateway · Hiker · arquivos · liquidação · conciliação        │
│ adquirentes · SPB/BACEN · antifraude · observabilidade       │
└──────────────────────────────────────────────────────────────┘
```

### 5.3 Separação entre plano transacional e plano analítico

| Aspecto | Gateway de Pagamentos | Sistema Vitrine |
|---|---|---|
| Finalidade | Processar e movimentar pagamentos | Explicar e acompanhar a operação |
| Escrita financeira | Responsável | Não permitida no fluxo normal |
| Latência | Baixa e determinística | Quase real-time e analítica |
| Banco principal | Operacional | Data warehouse/data mart próprio |
| Falha aceitável | Deve interromper ou degradar com controle | Pode exibir atraso explícito sem interromper o pagamento |
| Modelo de dados | Transacional e auditável | Dimensional, agregado e orientado à consulta |
| Usuários | Serviços e operadores autorizados | Personas do cliente, suporte, gestão e vendas |

### 5.4 Atualização dos dados

A experiência deve declarar o nível de frescor de cada área:

| Área | Meta inicial de atualização |
|---|---|
| Operação e incidentes | 1 a 5 minutos |
| Transações e status | Até 5 minutos, conforme fonte |
| Arquivos e Hiker | Até 5 minutos |
| Liquidação e conciliação | Conforme chegada dos retornos, com status de atraso |
| Indicadores executivos | 15 minutos ou atualização agendada |
| Relatórios históricos | Diária, com reprocessamento controlado |

O produto não deve prometer tempo real onde a fonte externa ou o processo de liquidação não fornecer essa garantia.

---

## 6. Componentes Principais

### 6.1 Portal Web

Aplicação multi-tenant com layout responsivo, navegação por módulos, filtros persistentes, drill-down, estados de carregamento e indicação de última atualização. O portal deve funcionar como produto independente, com identidade visual configurável por cliente sem duplicar código.

### 6.2 BFF e Query Service

Backend-for-Frontend responsável por:

- compor dados de múltiplos domínios em respostas voltadas à experiência;
- validar filtros e limites de consulta;
- aplicar autorização por tenant, papel e escopo;
- ocultar detalhes de armazenamento do frontend;
- usar cache para consultas repetidas;
- retornar metadados de atualização, qualidade e origem do dado.

O Query Service deve consultar agregações e modelos de leitura. Consultas que possam pressionar o data warehouse devem ser paginadas, limitadas e observáveis.

### 6.3 Ingestão de dados

Suportar, conforme disponibilidade do Gateway:

- consumo de eventos de `transacao_evento` e `hiker_auditoria`;
- CDC de tabelas operacionais;
- cargas incrementais de `fato_transacao`, arquivos e liquidações;
- ingestão de métricas técnicas e logs agregados;
- reprocessamento por janela ou `correlation_id`.

Cada registro deve carregar `tenant_id`, identificador de origem, versão do contrato, horário do evento, horário de ingestão e chave de deduplicação.

### 6.4 Data lake / landing zone

Armazena dados brutos e particionados por domínio e data, com controle de acesso e retenção. O armazenamento bruto permite reproduzir transformações quando uma regra de negócio ou métrica for corrigida.

### 6.5 Data warehouse e data marts

O warehouse concentra fatos e dimensões certificados. Data marts específicos podem otimizar experiências como operação, financeiro e risco, evitando um modelo monolítico difícil de evoluir.

### 6.6 Catálogo de métricas

Registro governado de cada indicador, contendo:

- nome técnico e nome exibido;
- definição de negócio e fórmula;
- granularidade;
- fonte e horário de atualização;
- filtros aplicáveis;
- responsável pela métrica;
- versão e histórico de alteração;
- regras de qualidade e limitações conhecidas.

### 6.7 Alertas e notificações

Motor que avalia regras sobre métricas, eventos e janelas temporais. Entrega notificações no portal e, conforme configuração, por e-mail, webhook ou integração corporativa. Alertas devem ter deduplicação, severidade, ciclo de vida e evidências anexadas.

### 6.8 Relatórios e BI embedded

A solução pode começar com dashboards nativos e evoluir para BI embedded quando houver necessidade de exploração ad hoc, governança corporativa ou grande volume de relatórios. O BI deve consumir a camada semântica certificada, nunca tabelas brutas.

---

## 7. Plataforma de Dados e BI

### 7.1 Modelo dimensional recomendado

```text
                         dim_tempo
                             │
 dim_cliente ───────┐        │        ┌──── dim_parceiro
 dim_meio_pagamento ├── fato_pagamento ─┤ dim_canal
 dim_status ────────┘        │        └──── dim_adquirente
                             │
                    dim_localidade / dim_risco

 fato_pagamento ─── fato_liquidacao ─── fato_conciliacao
        │
        ├── fato_arquivo
        ├── fato_hiker_passo
        └── fato_incidente
```

### 7.2 Fatos principais

| Fato | Granularidade | Uso |
|---|---|---|
| `fato_pagamento` | Uma transação ou operação financeira | Volume, conversão, status e valores |
| `fato_pagamento_evento` | Um evento de ciclo de vida | Linha do tempo, SLA e auditoria |
| `fato_arquivo` | Um arquivo recebido ou enviado | Operação batch, rejeição e atraso |
| `fato_hiker_passo` | Um passo de validação por arquivo | Qualidade de entrada e causas de erro |
| `fato_liquidacao` | Uma liquidação ou lote financeiro | Agenda, valor e atraso |
| `fato_conciliacao` | Uma ocorrência de conciliação | Divergência, aging e resolução |
| `fato_incidente` | Um alerta operacional agrupado | Impacto, resposta e recorrência |

### 7.3 Dimensões principais

- `dim_tempo`: dia, hora, dia útil, feriado, semana e período fiscal.
- `dim_cliente`: tenant e atributos não sensíveis do contrato.
- `dim_parceiro`: parceiro comercial, banco, adquirente ou originador.
- `dim_meio_pagamento`: PIX, cartão, boleto, TED, DOC e extensões futuras.
- `dim_canal`: API, VAN, SFTP, dashboard ou integração.
- `dim_status`: estados normalizados do Gateway e seus grupos analíticos.
- `dim_geografia`: país, estado, cidade ou região conforme contrato e LGPD.
- `dim_versao_layout`: layout, versão e configuração aplicada ao arquivo.

### 7.4 Camada semântica

A camada semântica deve impedir que cada tela ou relatório calcule o mesmo indicador de uma forma diferente. Exemplos de métricas certificadas:

```text
volume_processado = soma(valor_bruto)
quantidade_processada = contagem de transacoes distintas
indice_autorizacao = autorizadas / transacoes_submetidas
indice_falha = transacoes_com_falha / transacoes_submetidas
valor_liquidado = soma(valor_liquidado)
indice_conciliacao = transacoes_conciliadas / transacoes_liquidadas
tempo_medio_processamento = p95(data_evento_final - data_recebimento)
```

As fórmulas reais devem ser validadas com as áreas de negócio, especialmente para definir denominadores, reprocessamentos, cancelamentos, estornos e transações duplicadas.

### 7.5 Qualidade de dados

Checks mínimos:

- completude de `tenant_id`, identificador de origem e data do evento;
- unicidade de chaves de negócio e eventos;
- validade de status e meios de pagamento;
- reconciliação de quantidade e valor com a fonte;
- atraso de ingestão por domínio;
- detecção de duplicidade e regressão de volume;
- controle de schema e compatibilidade de versões.

Falhas de qualidade devem aparecer para o usuário como indicador de confiabilidade e também gerar alerta interno. Um número visualmente preciso, mas atrasado ou incompleto, é um risco de produto.

---

## 8. Indicadores e Painéis

### 8.1 Painel executivo

Exibir, no período selecionado:

- valor e quantidade processados;
- variação contra período anterior;
- taxa de autorização e conversão;
- valor liquidado e conciliado;
- transações pendentes, negadas e em revisão;
- incidentes abertos por severidade;
- disponibilidade percebida dos principais canais;
- tendência de custo, taxa ou margem quando esses dados forem contratualmente disponíveis.

Cada cartão deve permitir abrir a composição do número, com filtros preservados.

### 8.2 Cockpit operacional

- fila de arquivos em recebimento, validação, rejeição e carga;
- idade dos itens pendentes;
- etapas do Hiker com maior taxa de erro;
- saúde por parceiro, adquirente, canal e layout;
- eventos recentes e incidentes correlacionados;
- visão de capacidade, latência e taxa de falhas;
- lista de ações recomendadas, sempre distinguindo recomendação de comando executável.

### 8.3 Painel financeiro

- funil submetido, autorizado, liquidado e conciliado;
- agenda D+n e valores previstos;
- divergências por lote, parceiro e período;
- aging de pendências;
- estornos e cancelamentos;
- quebra entre valor bruto, taxas e valor líquido;
- exportação com trilha de solicitação e finalidade.

### 8.4 Painel de risco e compliance

- transações retidas e em revisão;
- distribuição de score antifraude, sem expor dados sensíveis;
- exceções de validação e recorrência;
- eventos de auditoria por transação e arquivo;
- indicadores de acesso, exportação e alteração de configuração;
- evidências vinculadas a um `correlation_id`.

### 8.5 Tela de detalhe

Para cada transação, arquivo ou lote, apresentar:

1. identificadores permitidos: NSU, E2E, nosso número ou `arquivo_id`;
2. resumo financeiro e status atual;
3. linha do tempo de eventos;
4. origem, parceiro, canal e layout;
5. erros, avisos e decisões do Hiker;
6. liquidação, conciliação e estornos;
7. links para incidentes e relatórios relacionados;
8. indicação clara de dados omitidos por segurança ou permissão.

---

## 9. Alertas e Inteligência Operacional

### 9.1 Tipos de regra

| Tipo | Exemplo |
|---|---|
| Limiar | Taxa de rejeição acima de 5% por 15 minutos |
| Anomalia | Volume 40% abaixo do padrão do mesmo horário |
| Ausência | Nenhum arquivo esperado recebido na janela contratada |
| Atraso | Lote aguardando liquidação além do SLA |
| Concentração | Falhas concentradas em um adquirente ou parceiro |
| Integridade | Diferença de valor entre fonte e data mart |
| Segurança | Exportação incomum ou acesso fora do padrão autorizado |

### 9.2 Ciclo de vida

```text
Detectado → Classificado → Notificado → Em investigação
     ↑                                      │
     └──────── Reaberto ← Resolvido ←──────┘
```

Cada alerta deve manter regra, valor observado, janela, escopo, severidade, evidências, destinatários e timestamps. Alertas repetidos devem ser agrupados em um incidente para evitar ruído.

### 9.3 Evolução de inteligência

A primeira versão deve privilegiar regras explicáveis. Depois, podem ser adicionados:

- previsão de volume e liquidação;
- detecção estatística de anomalias;
- recomendação de investigação;
- classificação de causa provável;
- resumo narrativo para executivos, sempre com links para evidências.

Qualquer uso de IA deve ser assistivo, auditável e claramente rotulado. Não deve tomar decisão financeira ou regulatória sem uma política específica, validação humana e controles apropriados.

---

## 10. Fluxos de Negócio

### 10.1 Atualização de uma transação

```text
Gateway
  │ publica evento
  ▼
Event bus / CDC
  │ valida contrato e deduplica
  ▼
Landing zone
  │ transforma e aplica regras de qualidade
  ▼
Data warehouse / data mart
  │ atualiza agregações e métricas
  ▼
Query Service
  │ aplica tenant, papel e filtros
  ▼
Portal / BI / alerta
```

### 10.2 Investigação operacional

```text
Usuário abre alerta
        │
        ▼
Incidente mostra impacto e janela
        │
        ▼
Drill-down por parceiro, canal, layout ou status
        │
        ▼
Detalhe de transação/arquivo e linha do tempo
        │
        ▼
Evidência exportável ou abertura de chamado
```

### 10.3 Atualização atrasada ou indisponibilidade analítica

Se a ingestão ou o warehouse estiver atrasado, o portal deve:

- manter o último dado válido com timestamp visível;
- exibir o estado `dados atrasados`;
- informar a área afetada e o atraso estimado quando disponível;
- impedir que o usuário interprete dado antigo como tempo real;
- registrar incidente técnico sem impactar o processamento do Gateway.

---

## 11. Segurança, Governança e Multi-tenancy

### 11.1 Isolamento por cliente

O modelo deve aplicar `tenant_id` em todas as entidades analíticas e utilizar row-level security ou mecanismo equivalente no serving. O tenant deve ser derivado da identidade autenticada e do escopo autorizado, nunca confiado a um filtro enviado pelo navegador.

### 11.2 Identidade e acesso

- SSO OIDC/SAML para clientes corporativos.
- MFA conforme política do cliente e do ambiente.
- RBAC para papéis e ABAC para escopos mais finos.
- Sessões, tokens e credenciais armazenados com proteção adequada.
- Provisionamento e desprovisionamento auditáveis.
- Acesso de suporte temporário, aprovado e com expiração.

### 11.3 Dados sensíveis

- Não ingerir PAN em claro.
- Mascarar identificadores e dados pessoais na interface.
- Minimizar IP, device fingerprint e informações do pagador conforme finalidade.
- Criptografar dados em trânsito e em repouso.
- Segregar dados de demonstração dos dados produtivos.
- Aplicar retenção, anonimização e exclusão conforme contrato e LGPD.

### 11.4 Auditoria

Registrar, no mínimo:

- login, logout e falhas de autenticação;
- consulta a dados sensíveis ou detalhados;
- exportação e compartilhamento de relatório;
- criação, alteração e desativação de alertas;
- alteração de usuários, papéis e escopos;
- acesso de suporte;
- versão das métricas e filtros usados em relatórios relevantes.

### 11.5 Ambiente demonstrativo para vendas

A vitrine comercial deve usar tenant separado, dados sintéticos e roteiros reproduzíveis. O modo demo pode simular incidentes, atrasos e recuperação, mas deve exibir claramente que os dados são demonstrativos. Nenhuma demonstração deve consultar dados reais de outro cliente.

---

## 12. Atributos de Qualidade

### 12.1 Metas iniciais

| Atributo | Meta proposta |
|---|---|
| Disponibilidade do portal | ≥ 99,5% mensal, exceto manutenção comunicada |
| Atualização operacional | P95 inferior a 5 minutos após evento disponível |
| Carregamento de visão executiva | P95 inferior a 3 segundos para filtros padrão |
| Consulta de detalhe | P95 inferior a 2 segundos, sem exportação |
| Isolamento de tenant | 100% das consultas filtradas por política de acesso |
| Integridade | Divergência de quantidade/valor monitorada e explicitada |
| Recuperação | Reprocessamento de janela sem duplicar fatos ou eventos |
| Escalabilidade | Crescer em leitores e processamento sem conexão direta ao OLTP |

As metas devem ser confirmadas com volume, retenção, número de tenants, frequência de eventos e ferramenta de BI escolhida.

### 12.2 Observabilidade da própria vitrine

Monitorar:

- atraso por estágio da pipeline;
- taxa de eventos rejeitados e duplicados;
- falhas de transformação;
- tempo e custo das consultas;
- cache hit rate;
- disponibilidade e latência do portal;
- quantidade de usuários e exportações;
- qualidade e completude por domínio;
- diferença entre fonte e modelo analítico.

---

## 13. Integrações e Contratos

### 13.1 Fontes de dados

| Fonte | Forma preferencial | Conteúdo |
|---|---|---|
| Gateway | Eventos, CDC ou API interna de leitura | transações, status e eventos |
| Hiker | Eventos e leitura de auditoria | passos, erros, avisos e veredictos |
| Arquivos | Eventos e metadados | recebimento, hash, layout e situação |
| Liquidação | CDC ou carga incremental | lotes, agenda, confirmação e valores |
| Conciliação | Eventos ou carga incremental | correspondências e divergências |
| Observabilidade | Métricas e logs agregados | latência, erros, disponibilidade e capacidade |

### 13.2 Contrato de evento analítico

Exemplo conceitual:

```json
{
  "event_id": "uuid",
  "event_type": "TransacaoStatusAlterado",
  "event_version": 1,
  "tenant_id": "cliente-123",
  "aggregate_id": "transacao-uuid",
  "occurred_at": "2026-08-26T12:00:00Z",
  "ingested_at": "2026-08-26T12:00:03Z",
  "correlation_id": "correlation-uuid",
  "source": "gateway-pagamentos",
  "payload": {
    "status_anterior": "EM_PROCESSAMENTO",
    "status_novo": "AUTORIZADA",
    "meio_pagamento": "PIX"
  }
}
```

O contrato deve definir compatibilidade, campos obrigatórios, política de reprocessamento, ordenação quando necessária, retenção e tratamento de dados pessoais.

### 13.3 BI como produto complementar

A arquitetura deve permitir três formas de consumo:

1. **Portal nativo**: experiência controlada, responsiva e adequada para operação diária.
2. **BI embedded**: exploração analítica dentro do contexto visual do produto.
3. **BI do cliente**: acesso governado a views, APIs ou exportações para o ambiente corporativo.

A camada de autorização deve permanecer sob controle do produto mesmo quando o cliente usa BI embedded ou exporta dados.

---

## 14. Roadmap de Produto

### Fase 1 — Produto demonstrável

- tenant demo com dados sintéticos;
- visão executiva;
- cockpit de operação;
- filtros, drill-down e detalhe de transação;
- indicadores de pagamento, arquivo e liquidação;
- autenticação e isolamento de tenant;
- atualização por carga agendada ou eventos disponíveis;
- roteiro comercial reproduzível.

### Fase 2 — Operação assistida

- alertas configuráveis;
- central de incidentes;
- linha do tempo de arquivo e Hiker;
- painel de conciliação;
- exportação auditada;
- notificações por e-mail/webhook;
- catálogo de métricas e checks de qualidade.

### Fase 3 — BI e inteligência

- BI embedded;
- relatórios agendados;
- previsão de volume e liquidação;
- detecção de anomalias explicável;
- benchmark privado por segmento ou histórico do próprio cliente;
- recomendações de investigação.

### Fase 4 — Produto escalável

- self-service de onboarding;
- personalização por plano e módulo;
- APIs públicas de consulta;
- marketplace de relatórios;
- SLA por camada de atualização;
- modelo de cobrança por módulos, usuários ou volume.

---

## 15. Decisões Arquiteturais (ADRs)

### ADR-001: Manter a vitrine separada do processamento transacional

**Contexto**: Consultas analíticas, relatórios e picos de usuários não podem afetar autorização, ingestão ou liquidação.

**Decisão**: Usar pipeline analítica e modelos de leitura próprios, alimentados por eventos, CDC ou cargas controladas.

**Consequências**: Maior segurança operacional e liberdade de evolução; exige governança de dados e aceitação de eventualidade no painel.

### ADR-002: Read-only por padrão

**Contexto**: Um segundo caminho de escrita poderia gerar divergência, duplicidade e risco financeiro.

**Decisão**: A vitrine apenas consulta, analisa, alerta e encaminha. Alterações financeiras permanecem no Gateway.

**Consequências**: Menor risco e escopo inicial mais claro; ações operacionais precisam de integração explícita no futuro.

### ADR-003: Camada semântica como fonte oficial de métricas

**Contexto**: Telas e ferramentas de BI podem calcular conversão, liquidação e falha de maneiras diferentes.

**Decisão**: Publicar métricas certificadas com fórmula, responsável, versão e qualidade.

**Consequências**: Consistência e auditabilidade; mudanças de definição exigem versionamento e comunicação.

### ADR-004: Multi-tenancy obrigatório desde a primeira versão

**Contexto**: O produto deve ser ofertável a vários clientes e não pode depender de cópias isoladas da aplicação.

**Decisão**: Incluir `tenant_id`, políticas de acesso, dados sintéticos e testes de isolamento desde o desenho inicial.

**Consequências**: Onboarding e evolução comercial mais simples; exige testes de segurança e governança rigorosos.

### ADR-005: Regras explicáveis antes de modelos preditivos

**Contexto**: Operações financeiras precisam entender por que um alerta foi criado.

**Decisão**: Começar com limiares, comparação histórica, ausência e integridade; evoluir para estatística e IA com evidências.

**Consequências**: Valor rápido e maior confiança; inteligência avançada entra depois de existir uma base de dados confiável.

---

## 16. Roteiro de Demonstração Comercial

Uma demonstração de 15 a 20 minutos pode seguir esta sequência:

1. **Visão executiva**: mostrar volume, valor, conversão, liquidação e alertas do dia.
2. **Mudar o período e o escopo**: filtrar um parceiro ou meio de pagamento sem perder o contexto.
3. **Encontrar uma anomalia**: abrir uma queda de autorização ou aumento de rejeições.
4. **Explicar o impacto**: mostrar quantidade, valor, janela e concentração da ocorrência.
5. **Investigar a jornada**: navegar até a transação ou arquivo e apresentar a linha do tempo.
6. **Conectar operação e financeiro**: demonstrar o efeito na liquidação ou conciliação.
7. **Mostrar governança**: destacar papéis, tenant, dados mascarados e trilha de exportação.
8. **Encerrar com evolução**: apresentar alertas, BI embedded e inteligência como módulos expansíveis.

A demonstração deve ser guiada por um cenário de negócio, não por uma lista de telas. O cliente precisa sair entendendo qual decisão a ferramenta permite tomar e quanto tempo pode economizar.

---

## 17. Premissas e Próximas Decisões

### 17.1 Premissas

- O Gateway continuará sendo a fonte de verdade transacional.
- Eventos ou mecanismos de leitura incremental poderão ser disponibilizados.
- O cliente aceitará eventualidade controlada para áreas analíticas.
- A primeira versão priorizará confiabilidade e experiência sobre amplitude de métricas.
- Dados de demonstração poderão ser gerados a partir de cenários sintéticos próximos da operação real.

### 17.2 Decisões a tomar

| Tema | Pergunta |
|---|---|
| Posicionamento | A vitrine será módulo incluso, add-on ou produto premium? |
| Tecnologia BI | Portal nativo, BI embedded, ferramenta externa ou combinação? |
| Frescor | Quais painéis exigem minutos e quais aceitam atualização diária? |
| Contrato de dados | Quais eventos e APIs o Gateway disponibilizará formalmente? |
| Multi-tenancy | Isolamento lógico, banco por cliente ou estratégia híbrida? |
| Retenção | Por quanto tempo manter fatos detalhados, agregados e eventos? |
| Métricas | Quem certifica fórmulas financeiras e operacionais? |
| Comercial | Quais módulos, limites e SLAs formarão os planos? |
| Suporte | Como alertas viram chamados e quais equipes recebem cada severidade? |

### 17.3 Primeiro incremento recomendado

Construir um vertical slice com um tenant sintético, um fluxo de transação, um fluxo de arquivo e um fluxo de liquidação. O incremento deve entregar uma visão executiva, um cockpit operacional, uma tela de detalhe, atualização incremental, isolamento de acesso e um alerta explicável. Esse recorte valida simultaneamente valor comercial, contrato de dados, experiência e viabilidade técnica.

---

## 18. Glossário

| Termo | Definição |
|---|---|
| **Vitrine de operação** | Produto complementar que apresenta a saúde, o fluxo e o desempenho da operação do cliente |
| **Operational Intelligence** | Uso combinado de dados operacionais, métricas, contexto e alertas para apoiar decisões |
| **BI** | Business Intelligence; práticas e ferramentas para análise e visualização de dados |
| **BFF** | Backend-for-Frontend; serviço que adapta APIs e dados para uma experiência específica |
| **CDC** | Change Data Capture; captura incremental de alterações em uma fonte |
| **Data mart** | Recorte analítico orientado a um domínio ou conjunto de necessidades |
| **Data warehouse** | Repositório analítico governado para consultas históricas e métricas |
| **Drill-down** | Navegação de um indicador agregado para suas dimensões e registros de origem |
| **Event bus** | Infraestrutura de distribuição de eventos entre produtores e consumidores |
| **Frescor do dado** | Tempo entre o evento na origem e sua disponibilidade para consulta |
| **Métrica certificada** | Indicador com definição, fórmula, origem, responsável e versão governados |
| **Multi-tenancy** | Capacidade de atender vários clientes com isolamento lógico e controle de acesso |
| **RLS** | Row-Level Security; política que limita linhas visíveis conforme identidade e escopo |
| **Read-only** | Operação que consulta dados sem alterar o estado financeiro da origem |
| **Tenant** | Cliente ou organização isolada dentro do produto |
| **Data lineage** | Rastreabilidade da origem, transformação e destino de um dado |
