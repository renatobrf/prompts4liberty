# Serviço Anti Fraude para Operação de Seguros

## Visão geral

Este documento descreve um serviço de anti-fraude para a operação de seguros simples. O serviço complementa a operação de seguro existente, oferecendo mecanismos de prevenção, detecção e investigação de fraudes em propostas, apólices, sinistros, certificados e prêmios.

## Objetivo

Construir um serviço de anti-fraude que permita:
- avaliar automaticamente riscos de fraude em novos contratos e sinistros
- identificar padrões suspeitos em apólices, clientes e pagamentos
- aplicar regras e pontuações para bloquear ou sinalizar eventos
- manter histórico de análises, ações e justificativas
- integrar com auditoria e processos de investigação

## Escopo do serviço

O serviço cobre as seguintes áreas:
- detecção de fraude em propostas de clientes
- análise de apólices emitidas e certificados
- monitoramento de sinistros e de valor indenizado
- verificação de prêmios, pagamentos e documentos associados
- classificação de casos como pendente, suspeito, confirmado ou negado

## Principais capacidades

- avaliação de riscos por evento:
  - proposta
  - apólice
  - sinistro
  - pagamento de prêmio
- regras de detecção configuráveis
- pontuação de fraude (score)
- motivo e categoria de suspeita
- acionamento de workflows de revisão manual
- registro de evidências e ações tomadas

## Entidades principais

- `ANALISE_FRAUDE`: análise de risco de fraude vinculada a um cliente, apólice, sinistro ou prêmio.
- `REGRA_FRAUDE`: regra de detecção reusável que pode ser aplicada em várias etapas do processo.
- `CASO_FRAUDE`: caso investigativo que agrupa evidências e ações de revisão.
- `EVIDENCIA_FRAUDE`: item de evidência coletado durante a análise.
- `ACAO_FRAUDE`: ação tomada sobre o caso ou evento, como bloqueio, notificação, liberação ou escalonamento.

## Arquitetura lógica

O serviço deve ser projetado como um componente de negócio que consome dados da operação de seguros e produz sinalizações de fraude.

Fluxo básico:
1. um novo cliente ou proposta é recebido
2. o serviço aplica regras e modelos de pontuação
3. um `ANALISE_FRAUDE` é gerado com resultado e justificativas
4. se o resultado é suspeito, um `CASO_FRAUDE` é aberto
5. um analista pode registrar `EVIDENCIA_FRAUDE` e executar `ACOES_FRAUDE`
6. o resultado final é integrado ao processo de emissão ou pagamento

## Regras de negócio sugeridas

- duplicidade de documentos ou dados de contato entre propostas diferentes
- divergência entre idade e sub-ramo de produto
- excesso de sinistros em curto período para mesmo cliente ou apólice
- sinistro com valor muito próximo ao limite de cobertura
- mudança de dados cadastrais após abertura de sinistro
- prêmio pago com formas de pagamento não usuais ou múltiplos pagamentos

## Tipos de fraude e estados

- tipos de fraude:
  - fraude documental
  - fraude de identidade
  - fraude por exagero de danos
  - fraude por omissão de informações
  - fraude de pagamento
- estados de análise:
  - pendente
  - suspeito
  - em investigação
  - confirmado
  - descartado

## Integração com o serviço de seguro simples

O serviço de anti-fraude deve ser integrado às etapas críticas do processo de seguro:
- na emissão de `APOLICE`
- na criação de `CERTIFICADO`
- no registro de `SINISTRO`
- na geração de `PREMIO`

Ele também pode expor alertas para uso em dashboards de compliance e relatórios gerenciais.

## Benefícios esperados

- redução de perdas financeiras por fraudes
- maior eficiência na revisão de operações suspeitas
- conformidade com controles internos e regulatórios
- melhoria na qualidade dos dados e consistência dos processos

## Distinção de responsabilidades

- o serviço de seguro mantém os dados operacionais de apólices, coberturas, sinistros e prêmios
- o serviço anti-fraude mantém as análises, sinais, casos e ações relacionadas a suspeitas
- as ações de bloqueio ou autorização devem ser aplicadas em conjunto com regras de negócio e aprovação humana
