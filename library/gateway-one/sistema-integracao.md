# Documento de Arquitetura de Software
## Sistema de Integracao de Clientes — Porta de Entrada para o Gateway de Pagamentos

| Atributo | Valor |
|---|---|
| Versao | 1.0 |
| Status | Proposta para validacao |
| Dominio | Integracao de clientes, cobranca, pagamentos e meios de pagamento |
| Papel | Produto de onboarding e camada de entrada do Gateway de Pagamentos |
| Publico | Clientes pequenos sem ERP, clientes corporativos, time de projetos e operacoes |
| Referencias | [Gateway de Pagamentos](./gateway-pagamentos-arquitetura-software.md) |
| Proposta de valor | Conectar qualquer cliente ao gateway com o menor acoplamento possivel |

---

## Indice

1. [Visao Geral](#1-visao-geral)
2. [Problema e Oportunidade](#2-problema-e-oportunidade)
3. [Proposta de Produto](#3-proposta-de-produto)
4. [Escopo e Objetivos](#4-escopo-e-objetivos)
5. [Personas e Casos de Uso](#5-personas-e-casos-de-uso)
6. [Visao Arquitetural](#6-visao-arquitetural)
7. [Componentes Principais](#7-componentes-principais)
8. [Modelo Canonico e Contratos](#8-modelo-canonico-e-contratos)
9. [Fluxos de Negocio](#9-fluxos-de-negocio)
10. [Onboarding de Clientes](#10-onboarding-de-clientes)
11. [Integracoes Externas](#11-integracoes-externas)
12. [Seguranca, Governanca e Compliance](#12-seguranca-governanca-e-compliance)
13. [Atributos de Qualidade](#13-atributos-de-qualidade)
14. [Operacao e Observabilidade](#14-operacao-e-observabilidade)
15. [Roadmap e Empacotamento](#15-roadmap-e-empacotamento)
16. [Decisoes Arquiteturais (ADRs)](#16-decisoes-arquiteturais-adrs)
17. [Premissas e Proximas Decisoes](#17-premissas-e-proximas-decisoes)
18. [Glossario](#18-glossario)

---

## 1. Visao Geral

O **Sistema de Integracao de Clientes** e uma plataforma multi-tenant que simplifica e padroniza a entrada de clientes no Gateway de Pagamentos. Ele recebe dados de cobranca e pagamentos por diferentes canais, converte cada origem para um **modelo canonico**, valida o conteudo, gera ou interpreta arquivos financeiros e encaminha mensagens ao gateway com rastreabilidade ponta a ponta.

A mesma plataforma atende dois perfis sem criar dois produtos independentes:

- **Cliente pequeno**: pode nao possuir ERP ou equipe de integracao. Utiliza portal, planilhas padronizadas, API simples ou arquivos gerados pelo sistema para cadastrar cobrancas e pagamentos.
- **Cliente grande**: ja possui ERP, sistema de cobranca ou tesouraria. Utiliza APIs, SFTP, webhooks, eventos ou conectores para integrar seus sistemas sem alterar seu modelo interno.

A proposta central e separar a complexidade da origem da complexidade do gateway:

```text
┌─────────────────────────────┐       ┌──────────────────────────────┐
│ Clientes pequenos           │       │ Clientes grandes             │
│ Portal · CSV · API simples  │       │ ERP · TMS · APIs · SFTP      │
└──────────────┬──────────────┘       └──────────────┬───────────────┘
               │                                     │
               └──────────────────┬──────────────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│              SISTEMA DE INTEGRACAO DE CLIENTES                       │
│                                                                      │
│ Adapters · Mapeamento · Modelo canonico · Validacao · Orquestracao   │
│ Idempotencia · Status · Eventos · Portal de onboarding · Auditoria   │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ contrato canonico e seguro
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         GATEWAY DE PAGAMENTOS                        │
│ API Layer · Hiker · configServerFiles · Bulk Files · liquidacao      │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.1 Principios de desenho

| Principio | Aplicacao |
|---|---|
| Uma porta de entrada | Todo cliente utiliza contratos e canais governados pelo Sistema de Integracao |
| Modelo canonico | O gateway nao precisa conhecer o ERP ou layout proprietario de cada cliente |
| Configuracao antes de codigo | Mapeamentos, layouts, regras e credenciais sao configuraveis e versionados |
| Nao perder o original | O payload ou arquivo de origem e preservado junto da versao normalizada |
| Idempotencia por contrato | Reenvios e retries nao criam cobrancas ou pagamentos duplicados |
| Assincrono por padrao | Operacoes de arquivo e processamento longo retornam protocolo e status consultavel |
| Falha explicavel | Erros indicam campo, origem, regra, acao recomendada e protocolo |
| Evolucao independente | Adaptadores podem mudar sem alterar o core do gateway |
| Tenant por padrao | Dados, credenciais, regras, limites e usuarios sao isolados por cliente |

---

## 2. Problema e Oportunidade

### 2.1 Problema de onboarding

Cada cliente chega com uma combinacao diferente de ERP, layout, identificadores, regras de negocio, frequencia de envio e capacidade tecnica. Sem uma camada padronizada, o time de projetos tende a criar integracoes ponto a ponto, aumentando prazo, custo de manutencao e risco operacional.

Os problemas mais recorrentes sao:

- cliente pequeno sem sistema para gerar remessa de cobranca ou pagamento;
- layouts proprietarios ou variacoes de CNAB 240 e CNAB 400;
- identificadores diferentes para contrato, cliente, parcela, titulo e pagamento;
- arquivos incompletos, duplicados, fora de ordem ou com totalizadores inconsistentes;
- necessidade de retorno de status em formatos diferentes do envio;
- falta de ambiente de homologacao e dados de teste reproduziveis;
- credenciais e regras mantidas manualmente em planilhas;
- impossibilidade de diagnosticar rapidamente se a falha esta no cliente, no adaptador ou no gateway.

### 2.2 Oportunidade de produto

O sistema transforma o onboarding em um processo repetivel e mensuravel. O time de projetos configura um tenant, escolhe um perfil de conectividade, publica um contrato e acompanha testes por evidencias. O cliente passa a ter uma porta de entrada coerente, mesmo que sua origem tecnica seja simples ou altamente integrada.

Indicadores de sucesso do produto:

- tempo entre kickoff e primeira transacao em homologacao;
- tempo entre homologacao aprovada e producao;
- percentual de mensagens aceitas na primeira tentativa;
- percentual de clientes atendidos sem desenvolvimento especifico;
- volume de reprocessamento manual por cliente;
- percentual de eventos com correlacao ponta a ponta.

---

## 3. Proposta de Produto

### 3.1 Nome e posicionamento

Nome recomendado: **Sistema de Integracao de Clientes**, com o conceito de produto **Integration Hub**.

> Uma porta de entrada configuravel para conectar clientes pequenos e corporativos ao Gateway de Pagamentos.

O Integration Hub nao substitui o ERP do cliente nem o processamento financeiro do gateway. Ele reduz o acoplamento entre as duas pontas, oferece recursos assistidos para clientes sem ERP e fornece governanca para integracoes corporativas.

### 3.2 Modos de uso

| Modo | Perfil | Entrada principal | Responsabilidade do sistema |
|---|---|---|---|
| Assistido | Pequeno porte | Portal, CSV/XLSX validado, API simples | Cadastrar dados, gerar arquivo, validar, transmitir e exibir retorno |
| Arquivo gerenciado | Pequeno ou medio porte | Upload, SFTP ou VAN | Interpretar layout, validar, converter e encaminhar |
| API canonica | Medio ou grande porte | REST/JSON e webhooks | Receber comandos, validar contrato, processar assincronamente e publicar eventos |
| Conector corporativo | Grande porte | ERP, TMS, tesouraria, mensageria ou SFTP | Adaptar modelo proprietario, controlar lotes e devolver status |

Todos os modos convergem para o mesmo modelo canonico e para os mesmos estados, protocolos, regras de idempotencia e trilhas de auditoria.

### 3.3 Capacidades do produto

| Capacidade | Resultado |
|---|---|
| Portal de onboarding | Configuracao guiada de cliente, usuario, canal e credenciais |
| Templates de dados | Planilhas e formularios para cobranca, pagamentos e recebimentos |
| Catalogo de conectores | Adaptadores reutilizaveis para ERPs, layouts e protocolos |
| Motor de mapeamento | Conversao declarativa entre origem e modelo canonico |
| Validacao antecipada | Erros detectados antes do envio ao gateway |
| Orquestracao | Encaminhamento, retry, timeout, fila e compensacao controlados |
| Consulta de protocolo | Visibilidade sobre arquivo, lote, item e resposta |
| Retornos e eventos | Webhook, API, arquivo de retorno ou notificacao no portal |
| Ambiente de homologacao | Testes com dados sinteticos e criterios de aceite |
| Administracao multi-tenant | Usuarios, papeis, limites, contratos e segregacao por cliente |

---

## 4. Escopo e Objetivos

### 4.1 Objetivos

| # | Objetivo |
|---|---|
| O1 | Criar uma porta de entrada unica para clientes do Gateway de Pagamentos |
| O2 | Reduzir o tempo e a variabilidade do onboarding de novos clientes |
| O3 | Atender clientes sem ERP com operacao assistida e geracao de arquivos |
| O4 | Atender clientes corporativos com APIs, arquivos e conectores reutilizaveis |
| O5 | Normalizar diferentes origens sem acoplar o gateway a cada cliente |
| O6 | Garantir idempotencia, rastreabilidade e diagnostico ponta a ponta |
| O7 | Permitir evolucao de layouts e contratos sem alterar integracoes ja homologadas |
| O8 | Dar ao time de projetos ferramentas para configurar, testar e promover clientes |

### 4.2 Escopo inicial

- Cadastro de tenant, parceiro, contas, produtos, usuarios e papeis.
- Portal para criacao assistida de cobrancas e ordens de pagamento.
- Importacao de CSV/TXT e planilhas com templates versionados.
- Upload e recepcao por SFTP para arquivos CNAB 240 e CNAB 400.
- API REST canonica para cobranca, pagamento, consulta e cancelamento conforme contrato do gateway.
- Mapeamento configuravel de campos e transformacoes simples.
- Validacao estrutural, semantica, financeira e de duplicidade.
- Geracao de arquivo de remessa a partir do modelo canonico.
- Interpretacao de arquivos de retorno e conversao para status canonico.
- Encaminhamento ao Gateway de Pagamentos por API ou fila.
- Protocolos de lote, arquivo e item com correlacao.
- Webhooks, consulta de status e exportacao de retorno.
- Homologacao guiada com checklist e evidencias.
- Auditoria de configuracao, transmissao, processamento e resposta.

### 4.3 Fora do escopo inicial

- Ser o ERP, CRM, contas a pagar ou sistema contabil do cliente.
- Manter o ledger financeiro oficial do gateway.
- Autorizar diretamente transacoes junto a adquirentes ou ao SPB.
- Criar regras regulatórias fora do dominio de integracao.
- Corrigir silenciosamente dados recebidos do cliente.
- Armazenar PAN em claro ou operar como cofre de dados de cartao.
- Desenvolver um conector exclusivo antes de avaliar reutilizacao por configuracao.

---

## 5. Personas e Casos de Uso

| Persona | Necessidade | Recurso |
|---|---|---|
| Gerente de projetos | Repetir o onboarding com controle de etapas | Wizard, templates, checklist, homologacao e promocao |
| Analista de integracao | Mapear campos e investigar falhas | Editor de contrato, amostras, simulacao e diagnostico |
| Cliente pequeno | Operar sem ERP | Portal, importacao simples, geracao de remessa e retorno legivel |
| Cliente corporativo | Integrar o ERP sem customizacao excessiva | API, SFTP, conector, eventos e contrato versionado |
| Operador financeiro | Acompanhar lotes e excecoes | Fila de processamento, protocolos e reprocessamento autorizado |
| Suporte | Responder onde a operacao parou | Linha do tempo e correlacao entre origem e gateway |
| Compliance | Comprovar acesso e processamento | Auditoria, retencao, segregacao e trilha imutavel |
| Administrador | Controlar acesso e credenciais | RBAC, escopos, rotacao e limites por tenant |

### 5.1 Casos prioritarios

1. Criar cobrancas manualmente pelo portal e transmitir ao gateway.
2. Importar uma planilha validada e gerar remessa no layout acordado.
3. Receber um arquivo CNAB do ERP, validar e encaminhar ao gateway.
4. Receber retorno bancario ou do gateway e disponibilizar status canonico.
5. Submeter pagamentos por API e consultar cada item por protocolo.
6. Reenviar uma mensagem com seguranca sem duplicar a operacao.
7. Identificar falha de mapeamento antes da promocao para producao.
8. Trocar a versao de um layout mantendo a versao anterior durante a transicao.
9. Devolver ao cliente um erro detalhado sem expor dados de outro tenant.

---

## 6. Visao Arquitetural

### 6.1 Estilo arquitetural

A solucao adota uma arquitetura **multi-tenant, orientada a contratos, configuravel e dirigida por eventos**. O fluxo sincrono confirma recebimento e validade basica; o processamento de arquivos, lotes e chamadas ao gateway ocorre de forma assincrona.

```text
┌────────────────────────────────────────────────────────────────────┐
│ Canais de entrada                                                  │
│ Portal · REST API · SFTP · VAN · Webhook · mensageria              │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Edge e controle                                                    │
│ API Gateway · mTLS/API Key · OAuth2 · rate limit · tenant context   │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Integration Hub                                                    │
│ Ingestao · classificacao · parser · mapeamento · validacao         │
│ idempotencia · orquestracao · lote · protocolo · retorno           │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Plataforma de contratos                                            │
│ Catalogo de layouts · schemas · regras · conectores · versoes       │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│ Gateway de Pagamentos                                              │
│ API Layer · Hiker · configServerFiles · Bulk Files · liquidacao     │
└────────────────────────────────────────────────────────────────────┘
```

### 6.2 Plano de controle e plano de dados

| Plano | Responsabilidade | Exemplos |
|---|---|---|
| Plano de controle | Configurar e governar a integracao | Tenant, usuarios, canais, layouts, mapeamentos, limites e promocao |
| Plano de dados | Transportar e processar operacoes | Arquivos, mensagens canonicas, lotes, respostas e eventos |

A separacao evita que uma alteracao administrativa bloqueie o processamento de uma operacao ja recebida. Configuracoes promovidas devem ser imutaveis; uma mudanca cria nova versao.

### 6.3 Estrategia de implantacao

A topologia pode operar em cloud, on-premises ou hibrida. O padrao recomendado e manter o Integration Hub em ambiente controlado, com conectividade privada ou mTLS com o gateway e com os sistemas corporativos.

- **SaaS multi-tenant**: indicado para clientes pequenos e onboarding rapido.
- **Instancia dedicada**: indicada quando isolamento, residencia de dados ou politica corporativa exigirem.
- **Agente/connector on-premises**: indicado quando o ERP nao pode expor endpoints ou arquivos para a internet.

A escolha deve ser uma decisao de onboarding, nao uma bifurcacao do modelo de dominio.

---

## 7. Componentes Principais

### 7.1 Portal de Onboarding e Operacao

Permite ao time de projetos e aos usuarios autorizados:

- criar e configurar tenants;
- escolher o perfil de integracao;
- cadastrar contas, produtos e regras de negocio;
- carregar amostras e validar layouts;
- acompanhar protocolos, lotes, arquivos e itens;
- consultar erros e baixar retornos conforme permissao;
- executar o checklist de homologacao;
- promover uma configuracao aprovada para producao.

O portal nao deve executar transacoes financeiras fora dos mesmos servicos e contratos usados pelos demais canais.

### 7.2 API Gateway e Edge de Integracao

Concentra preocupacoes transversais:

- terminacao TLS e mTLS;
- autenticacao e autorizacao;
- identificacao de tenant e parceiro;
- rate limit, quota e tamanho maximo;
- validacao inicial de schema;
- `correlation_id`, `idempotency_key` e auditoria de acesso;
- roteamento para APIs de ingestao e consulta.

A camada de edge nao substitui a validacao de negocio nem o Hiker.

### 7.3 Ingestion Service

Recebe arquivos e mensagens, calcula hash, registra metadados, armazena o original e cria um protocolo. O componente deve responder rapidamente com `RECEBIDO` ou rejeitar a entrada por erro basico de contrato.

### 7.4 Adapter Runtime

Executa conectores registrados no catalogo. Um adapter pode:

- interpretar CSV, TXT, CNAB 240, CNAB 400, JSON ou XML;
- transformar campos para o modelo canonico;
- gerar arquivos de remessa;
- interpretar arquivos de retorno;
- comunicar-se com REST, SFTP, MQ ou agente on-premises;
- aplicar regras de delimitador, encoding, mascara, casas decimais e datas.

Adapters nao devem conter regras financeiras especificas que pertencem ao modelo canonico ou ao gateway.

### 7.5 Contract and Mapping Registry

Catalogo versionado de:

- schemas de entrada e saida;
- layouts e suas versoes;
- mapeamentos de campos;
- transformacoes permitidas;
- regras de obrigatoriedade e dominio;
- conectores e versoes;
- vigencia por tenant e canal.

Uma configuracao ativa deve apontar explicitamente para todas as versoes usadas em uma execucao.

### 7.6 Validation Service

Executa validacoes em camadas:

1. **Tecnica**: encoding, tamanho, delimitador, assinatura e estrutura.
2. **Contrato**: campos obrigatorios, tipo, formato e dominio.
3. **Semantica**: relacionamento entre cliente, contrato, parcela e conta.
4. **Financeira**: valores, totalizadores, datas e tolerancias.
5. **Idempotencia**: chave de negocio, hash, lote e tentativa.
6. **Compliance**: dados sensiveis, permissao e regras aplicaveis.

Os erros devem ser estruturados, com severidade `ERRO`, `AVISO` ou `BLOQUEIO`.

### 7.7 Orchestrator e Processing Workers

Controla a maquina de estados, filas, retentativas, timeouts, circuit breakers e encaminhamento ao gateway. Workers devem ser stateless sempre que possivel; o estado persistente fica nos protocolos e eventos.

### 7.8 Status and Return Service

Consolida respostas do gateway, retornos bancarios e eventos de processamento. Pode entregar o resultado por:

- consulta REST;
- webhook assinado;
- arquivo de retorno;
- portal;
- evento em fila ou topico.

### 7.9 Audit and Observability Service

Registra eventos de negocio e tecnicos sem alterar o original. Publica metricas, logs estruturados e traces com correlacao entre cliente, arquivo, lote, item e gateway.

---

## 8. Modelo Canonico e Contratos

### 8.1 Entidades canonicas

| Entidade | Granularidade | Exemplos de identificadores |
|---|---|---|
| Cliente | Participante ou titular de uma operacao | `cliente_id`, documento tokenizado |
| Contrato | Relacao comercial ou financeira | `contrato_id`, referencia_externa |
| Cobranca | Obrigacao a receber | `cobranca_id`, `nosso_numero`, parcela |
| Ordem de pagamento | Instruicao de pagamento | `ordem_pagamento_id`, referencia_externa |
| Transacao | Operacao enviada ao gateway | `transacao_id`, NSU, E2E ID |
| Arquivo | Unidade fisica recebida ou gerada | `arquivo_id`, hash SHA-256 |
| Lote | Conjunto logico de itens | `lote_id`, totalizadores |
| Item | Unidade processavel do lote | `item_id`, chave de idempotencia |
| Evento | Mudanca ou fato observavel | `evento_id`, timestamp, origem |

### 8.2 Exemplo de contrato canonico

```json
{
  "schema_version": "1.0",
  "tenant_id": "tenant-001",
  "operation": "COBRANCA",
  "idempotency_key": "cliente-a|contrato-123|parcela-04|2026-08-26",
  "external_reference": "ERP-987654",
  "customer": {
    "external_id": "CLI-1001",
    "document_token": "doc-token-abc"
  },
  "contract": {
    "external_id": "CTR-123",
    "installment": 4,
    "due_date": "2026-09-10"
  },
  "amount": {
    "currency": "BRL",
    "gross": "125.90"
  },
  "payment_method": "BOLETO",
  "source": {
    "system": "erp-cliente",
    "channel": "SFTP",
    "file_id": "file-001",
    "line_number": 18
  }
}
```

Valores monetarios devem ser representados como `DECIMAL` ou string decimal no contrato, nunca como `FLOAT`.

### 8.3 Contrato de resposta assincrona

```json
{
  "protocol": "int-20260826-000001",
  "tenant_id": "tenant-001",
  "status": "RECEBIDO",
  "accepted_at": "2026-08-26T12:00:00Z",
  "correlation_id": "corr-abc-123",
  "links": {
    "status": "/v1/integracoes/int-20260826-000001"
  }
}
```

O protocolo representa o recebimento e nao significa autorizacao, liquidacao ou conciliacao. Esses estados devem ser consultados no retorno do processamento.

### 8.4 Chaves de idempotencia

A idempotencia deve ser avaliada em camadas:

| Camada | Chave sugerida |
|---|---|
| Arquivo | `tenant_id + sha256` |
| Lote | `tenant_id + referencia_externa_lote` |
| Item | `tenant_id + idempotency_key` |
| Requisicao API | `tenant_id + endpoint + idempotency_key` |
| Evento | `source_event_id + event_type` |

O sistema deve devolver o resultado original quando receber uma repeticao da mesma chave, em vez de criar nova operacao.

---

## 9. Fluxos de Negocio

### 9.1 Cliente pequeno: cobranca assistida

```text
Cliente → Portal → formulario ou planilha
                  │
                  ▼
          Validacao antecipada
                  │
          ┌───────┴────────┐
          │                │
       rejeitada         valida
          │                │
   erros acionaveis       ▼
                    modelo canonico
                         │
                         ▼
                  gera remessa/layout
                         │
                         ▼
                    Gateway de Pagamentos
                         │
                         ▼
                    retorno e protocolo
```

O cliente pode criar uma operacao individual ou um lote. A geracao do arquivo deve registrar a versao do layout, os totalizadores e a origem de cada campo.

### 9.2 Cliente grande: integracao com ERP

```text
ERP → API/SFTP/Agente → Ingestion → Adapter → Canonical Model
                                             │
                                             ▼
                                       Validation
                                             │
                                             ▼
                                      Orchestrator
                                             │
                                             ▼
                                      Gateway API
                                             │
                                             ▼
                        webhook/evento/arquivo de retorno → ERP
```

O Integration Hub nao deve fazer polling agressivo no ERP. Quando possivel, utiliza eventos, arquivos de retorno ou callbacks assinados.

### 9.3 Recebimento de retorno

1. Receber arquivo, evento ou resposta do gateway.
2. Validar autenticidade, integridade e tenant.
3. Identificar layout e versao do contrato.
4. Converter o retorno para o modelo canonico.
5. Correlacionar por protocolo, referencia externa e chave de negocio.
6. Atualizar status do arquivo, lote e item.
7. Publicar o retorno no canal configurado pelo cliente.
8. Registrar divergencias sem descartar o original.

### 9.4 Reprocessamento

Reprocessamento exige permissao e motivo. O sistema deve permitir escolher entre:

- repetir apenas a etapa que falhou;
- reexecutar a transformacao com nova configuracao;
- reenviar ao gateway, somente quando a idempotencia garantir seguranca;
- gerar um novo lote derivado, preservando o lote original.

Nunca se deve alterar retroativamente o resultado historico de uma execucao.

---

## 10. Onboarding de Clientes

### 10.1 Etapas padronizadas

| Etapa | Saida obrigatoria |
|---|---|
| Descoberta | Matriz de sistemas, operacoes, volumes, frequencias e responsaveis |
| Classificacao | Perfil assistido, arquivo, API ou conector corporativo |
| Contrato | Layout, schema, identificadores, regras e retorno acordados |
| Configuracao | Tenant, usuarios, canais, credenciais e limites |
| Mapeamento | Campos de origem associados ao modelo canonico |
| Teste tecnico | Amostras processadas com erros e evidencias |
| Homologacao | Criterios de aceite assinados pelo cliente e projeto |
| Promocao | Configuracao imutavel publicada em producao |
| Hypercare | Monitoramento reforcado e plano de reversao |

### 10.2 Artefatos do projeto

O projeto deve produzir, no minimo:

- ficha do cliente e tenant;
- matriz de capacidades e operacoes;
- catalogo de identificadores de negocio;
- amostras anonimizadas ou sinteticas;
- contrato de entrada e retorno;
- mapeamento de campos;
- regras de validacao e tolerancia;
- tabela de erros e tratamento;
- volumetria, janela e SLA;
- matriz de acessos e credenciais;
- plano de testes e criterios de aceite;
- plano de suporte, reprocessamento e contingencia.

### 10.3 Criterios de aceite

Um cliente pode ser promovido quando:

- todos os canais aprovados autenticam corretamente;
- arquivos validos sao aceitos e arquivos invalidos sao rejeitados com causa;
- totalizadores de entrada e saida sao reconciliados;
- chaves de idempotencia foram testadas com reenvio;
- retornos sao correlacionados ao item correto;
- timeouts, indisponibilidade e retry foram exercitados;
- usuarios e papeis foram validados;
- evidencias e logs atendem ao periodo de retencao definido;
- existe procedimento de rollback ou desativacao da configuracao.

### 10.4 Recomendacao para o time de projetos

O time deve manter um **catalogo de perfis de onboarding**, e nao uma lista de projetos completamente customizados:

- Perfil A: portal e planilha;
- Perfil B: upload/SFTP com layout padrao;
- Perfil C: API canonica;
- Perfil D: ERP com mapeamento configuravel;
- Perfil E: conector especifico, somente quando nao houver cobertura por configuracao.

Essa classificacao torna prazo, custo, riscos e dependencias visiveis antes do inicio da implementacao.

---

## 11. Integracoes Externas

| Integracao | Protocolo | Uso | Observacoes |
|---|---|---|---|
| Gateway de Pagamentos | REST, eventos ou fila | Enviar operacoes e receber status | Contrato canonico e correlacao obrigatorios |
| ERP do cliente | REST, SOAP, SFTP, MQ ou agente | Origem e destino de dados | Adapter isolado por sistema |
| Banco/VAN | SFTP, MQ ou arquivos | Remessa e retorno CNAB | Integridade, hash e controle de duplicidade |
| Portal de identidade | OAuth2/OIDC, SAML ou mTLS | Login e federacao | RBAC e tenant context |
| Notificacao | Webhook, e-mail ou mensageria | Entrega de status e alertas | Webhook assinado e retry controlado |
| Armazenamento | Object storage | Originais, retornos e evidencias | Criptografia e politica de retencao |
| Observabilidade | Logs, metricas e traces | Operacao e auditoria tecnica | Correlacao ponta a ponta |

### 11.1 Contrato com o Gateway

O Integration Hub deve consumir o Gateway como um cliente governado, utilizando:

- API Gateway e endpoints versionados;
- mTLS e credencial por tenant ou parceiro;
- `correlation_id` propagado;
- `idempotency_key` propagada;
- timeout e retry conforme contrato;
- consulta de status para operacoes assincronas;
- eventos de retorno quando disponiveis.

O Hiker continua sendo o componente responsavel pela travessia e validacao de arquivos dentro do gateway. O Integration Hub realiza a adaptacao e a validacao de entrada, sem duplicar silenciosamente a regra interna do Hiker.

---

## 12. Seguranca, Governanca e Compliance

### 12.1 Identidade e acesso

- mTLS para integracoes corporativas e SFTP quando aplicavel;
- OAuth2/OIDC para portal e APIs de usuarios;
- API Key apenas como identificacao complementar, nunca como unico controle para operacoes sensiveis;
- RBAC com escopo por tenant, ambiente, canal e operacao;
- segregacao entre configuracao, aprovacao e promocao;
- rotacao de segredos e certificados sem reimplantar o adapter;
- acesso de suporte temporario, justificado e auditado.

### 12.2 Protecao de dados

- criptografia em transito com TLS 1.2 ou superior;
- criptografia em repouso para banco, filas e object storage;
- mascaramento de documentos, contas e dados pessoais em logs;
- tokenizacao quando houver dado sensivel de cartao;
- nenhuma captura de PAN em logs, traces, arquivos de diagnostico ou ambiente de homologacao;
- minimizacao de dados e politica de retencao alinhada a LGPD e contratos.

### 12.3 Integridade e auditoria

- SHA-256 para arquivos recebidos e gerados;
- assinatura ou HMAC em webhooks;
- eventos append-only para configuracao, processamento e promocao;
- versionamento de schemas, layouts e mapeamentos;
- trilha de quem alterou, aprovou, publicou ou reprocessou;
- preservacao do original, normalizado, resultado e erro.

### 12.4 Isolamento multi-tenant

Todo comando deve carregar e validar `tenant_id` no contexto autenticado. O tenant nao deve ser confiado apenas ao payload enviado pelo cliente.

O isolamento deve existir em:

- autorizacao de API e portal;
- chaves e segredos;
- filas e topicos, quando necessario;
- tabelas e consultas;
- object storage;
- logs, metricas e exportacoes;
- cache e dados temporarios.

---

## 13. Atributos de Qualidade

### 13.1 Disponibilidade e desempenho

| Requisito | Meta inicial |
|---|---|
| API de recebimento | >= 99,9% mensal |
| Portal | >= 99,5% mensal |
| Confirmacao de recebimento API | P95 < 500 ms, sem incluir processamento assincrono |
| Inicio do processamento de arquivo | 95% dos arquivos em ate 2 minutos |
| Consulta de protocolo | P95 < 300 ms para dados recentes |
| Integridade do processamento | 100% dos lotes com totalizadores registrados |

As metas finais devem ser ajustadas por perfil, volume, horario de janela e dependencia do cliente.

### 13.2 Escalabilidade

- workers horizontais por tipo de adapter e fila;
- particionamento por tenant, arquivo ou lote;
- limites de concorrencia por cliente;
- backpressure para proteger o gateway;
- object storage para arquivos grandes, evitando payloads excessivos no banco;
- consultas de status separadas do processamento de itens;
- configuracao de capacidade por perfil de onboarding.

### 13.3 Resiliencia

- retries com backoff e limite por erro;
- dead-letter queue para mensagens que exigem intervencao;
- circuit breaker para dependencias indisponiveis;
- timeout explicito por canal e operacao;
- retomada de arquivo por particao quando suportada;
- idempotencia em todas as fronteiras de entrega;
- reconciliacao de totalizadores antes do encerramento do lote.

### 13.4 Compatibilidade e evolucao

- contratos versionados com politica de deprecacao;
- coexistencia de duas versoes durante migracao;
- adapter desacoplado do nucleo por interface estavel;
- transformacoes declarativas testaveis;
- compatibilidade retroativa documentada;
- dados originais preservados para reprocessamento.

---

## 14. Operacao e Observabilidade

### 14.1 Linha do tempo operacional

Cada operacao deve permitir a consulta desta sequencia:

```text
Origem → recebimento → classificacao → mapeamento → validacao
       → lote → envio ao gateway → resposta → retorno ao cliente
```

A linha do tempo deve mostrar timestamp, componente, versao do contrato, resultado, motivo de falha e `correlation_id`.

### 14.2 Metricas essenciais

| Grupo | Metricas |
|---|---|
| Entrada | arquivos, mensagens, bytes, canais e taxa de rejeicao |
| Qualidade | erros por campo, layout, adapter e tenant |
| Processamento | tempo por etapa, backlog, retry e dead-letter |
| Gateway | latencia, HTTP status, timeout e indisponibilidade |
| Negocio | itens aceitos, rejeitados, duplicados e processados |
| Onboarding | tempo por etapa, testes aprovados e retrabalho |
| Seguranca | falhas de autenticacao, acessos negados e rotacao |

### 14.3 Alertas

Alertas devem ser acionaveis e considerar tenant, severidade e impacto. Exemplos:

- arquivo esperado nao recebido dentro da janela;
- aumento anormal de rejeicoes para um layout;
- backlog acima do limite por cliente;
- falhas consecutivas no gateway;
- retorno sem correlacao;
- expiracao proxima de certificado;
- divergencia de totalizadores;
- repeticao de chave de idempotencia com payload diferente.

### 14.4 Tratamento de incidentes

O protocolo de incidente deve distinguir falha de origem, falha de contrato, falha de adapter, indisponibilidade do gateway e erro de negocio. O suporte deve poder fornecer ao cliente o protocolo e a causa sem expor detalhes internos desnecessarios ou dados de outros tenants.

---

## 15. Roadmap e Empacotamento

### 15.1 Fases sugeridas

| Fase | Entregas |
|---|---|
| MVP | Portal, tenant, CSV template, API canonica, protocolo, validacao e envio ao gateway |
| Operacao de arquivos | SFTP, CNAB 240/400, geracao de remessa, retorno e totalizadores |
| Corporativo | Mapeamento configuravel, webhooks, filas, agente on-premises e conectores |
| Escala | Catalogo self-service, observabilidade avancada, particionamento e quotas dinamicas |
| Produto ampliado | Marketplace de adapters, simulador de homologacao e BI de integracao |

### 15.2 Pacotes comerciais

| Pacote | Indicado para | Capacidades |
|---|---|---|
| Start | Clientes pequenos | Portal, templates, API simples, remessa e retorno |
| Standard | Clientes medios | SFTP, layouts configuraveis, webhooks e operacao assistida |
| Enterprise | Grandes clientes | API completa, conectores, agente privado, SLA e observabilidade dedicada |
| Dedicated | Requisitos especiais | Ambiente dedicado, residencia de dados e politicas customizadas |

O empacotamento comercial deve variar limites, suporte e isolamento, sem criar contratos de dados incompatíveis entre os pacotes.

---

## 16. Decisoes Arquiteturais (ADRs)

### ADR-001: Modelo canonico entre clientes e gateway

**Contexto**: Cada cliente possui identificadores, layouts e sistemas diferentes.

**Decisao**: O Integration Hub converte entradas para um modelo canonico versionado antes de encaminhar ao Gateway de Pagamentos.

**Consequencias**: Reduz acoplamento e facilita reuso de adapters. Exige governanca rigorosa do modelo e mapeamentos.

### ADR-002: Um produto com modos de entrada diferentes

**Contexto**: Clientes pequenos precisam de operacao assistida; clientes grandes precisam de integracao corporativa.

**Decisao**: Oferecer portal, arquivo, API e conectores sobre o mesmo nucleo de protocolos, validacao e status.

**Consequencias**: Aumenta o alcance comercial sem duplicar dominio. O portal nao pode criar regras paralelas aos canais tecnicos.

### ADR-003: Configuracao versionada antes de desenvolvimento especifico

**Contexto**: Variacoes de layout e mapeamento sao frequentes durante onboarding.

**Decisao**: Priorizar schemas, mapeamentos e transformacoes configuraveis; criar adapter customizado apenas quando a configuracao nao for suficiente.

**Consequencias**: Menor prazo de onboarding e maior reuso. Requer testes, limites para transformacoes e revisao das configuracoes.

### ADR-004: Processamento assincrono para arquivos e lotes

**Contexto**: Arquivos e lotes podem ser grandes e dependem do gateway, banco ou VAN.

**Decisao**: Confirmar recebimento com protocolo e processar o restante por filas e workers.

**Consequencias**: Maior resiliencia e escala. Clientes precisam consumir status ou retornos, e o contrato deve definir estados intermediarios.

### ADR-005: Original imutavel e normalizacao rastreavel

**Contexto**: Diagnostico, auditoria e reprocessamento exigem conhecer exatamente o dado recebido.

**Decisao**: Preservar original, hash, versao do adapter, modelo canonico e resultado de cada etapa.

**Consequencias**: Aumenta custo de armazenamento e governanca, mas permite explicar e reproduzir decisoes.

### ADR-006: Integration Hub nao substitui o Hiker nem o gateway

**Contexto**: A camada de cliente precisa validar entradas, mas o gateway continua dono do processamento financeiro e da travessia interna de arquivos.

**Decisao**: O Hub faz validacao antecipada e adaptacao; o Gateway permanece autoridade para autorizacao, carga, status financeiro e liquidacao.

**Consequencias**: Evita duplicidade de responsabilidade e preserva contratos claros entre produtos.

---

## 17. Premissas e Proximas Decisoes

Antes da implementacao, o time deve confirmar:

1. Quais operacoes entram no MVP: cobranca, pagamento, PIX, boleto ou todas?
2. O modelo canonico sera definido pelo Gateway de Pagamentos ou por um contrato compartilhado?
3. Quais layouts CNAB e bancos devem ser priorizados pelos primeiros clientes?
4. O portal permitira criacao individual, importacao de planilha ou ambos?
5. Qual sera o mecanismo de armazenamento e retencao de arquivos originais?
6. Quais canais exigem VAN, SFTP, agente on-premises ou conectividade privada?
7. O Gateway oferece eventos de retorno ou o Hub precisara consultar status?
8. Qual politica de idempotencia sera adotada para cada tipo de operacao?
9. Quais metas de volume, SLA e janela devem definir os perfis Start, Standard e Enterprise?
10. Quais dados podem ser visualizados pelo cliente, suporte, projeto e compliance?
11. Quem aprova uma configuracao e quem pode promove-la para producao?
12. Qual criterio torna um adapter customizado justificavel e reutilizavel?

A primeira prova de conceito recomendada e um fluxo completo de cobranca: **planilha de cliente pequeno → modelo canonico → remessa → Gateway → retorno → status no portal**. Em paralelo, o mesmo modelo deve ser exercitado por uma chamada de API de um cliente corporativo. O objetivo e provar que os dois perfis convergem para o mesmo protocolo e a mesma trilha operacional.

---

## 18. Glossario

| Termo | Definicao |
|---|---|
| Adapter | Componente que traduz protocolo, layout ou modelo de um sistema externo |
| API canonica | API com contrato comum, independente do ERP de origem |
| CNAB 240 | Layout Febraban com registros de 240 bytes |
| CNAB 400 | Layout Febraban com registros de 400 bytes |
| Correlation ID | Identificador para rastrear uma operacao entre componentes |
| ERP | Sistema de gestao empresarial do cliente |
| Event-driven | Arquitetura em que fatos sao comunicados por eventos |
| Integration Hub | Nome conceitual da plataforma de integracao de clientes |
| Idempotencia | Propriedade que permite repetir uma operacao sem duplicar seu efeito |
| Lote | Conjunto logico de itens processados em uma mesma operacao |
| Modelo canonico | Representacao comum usada entre origens e o gateway |
| Onboarding | Processo de configuracao, teste e entrada de um novo cliente |
| Protocolo | Identificador consultavel do recebimento e processamento |
| Tenant | Unidade isolada de cliente dentro da plataforma multi-tenant |
| Webhook | Notificacao HTTP enviada para um endpoint do cliente |
| Hiker | Componente do gateway responsavel pela travessia e validacao de arquivos |
| configServerFiles | Componente do gateway que centraliza regras de layouts |
| Bulk Files | Pipeline do gateway para processamento de arquivos em lote |
