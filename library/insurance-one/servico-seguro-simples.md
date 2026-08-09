# Serviço Seguro Simples

## Visão geral

Este documento descreve um serviço de seguro simples para uma base relacional. O serviço suporta seguro de apólice com produtos de vida, auto, proteção financeira e garantia estendida, incluindo apólice, certificado, cobertura, risco, sinistro, cliente, produto e prêmio.

## Objetivo

Criar um modelo de dados relacional que permita registrar:
- clientes e seus contratos
- produtos de seguro e suas características
- apólices emitidas e certificados gerados
- coberturas contratadas por apólice
- riscos avaliados para cada apólice
- sinistros registrados e valores de indenização
- premiações e recebimento de prêmios

## Produtos suportados

Produtos de seguro contemplados:
- Vida
- Auto
- Proteção Financeira
- Garantia Estendida

## Escopo do serviço

O serviço cobre as seguintes operações básicas:
- cadastro e consulta de clientes
- cadastro de produtos de seguro
- emissão de apólices e certificados
- definição de coberturas associadas à apólice
- registro de riscos relevantes para a apólice
- abertura e gerenciamento de sinistros
- cálculo e cobrança de prêmios

## Principais entidades

- `CLIENTE`: pessoa física ou jurídica que contrata o seguro.
- `PRODUTO`: produto de seguro oferecido, com categoria e regras básicas.
- `APOLICE`: contrato de seguro entre cliente e seguradora.
- `CERTIFICADO`: documento emitido para formalizar a vigência de uma apólice.
- `COBERTURA`: cobertura contratada dentro de uma apólice.
- `RISCO`: elemento de risco vinculado à apólice, usado na precificação e aceitação.
- `SINISTRO`: evento de perda ou dano comunicado pelo segurado.
- `PREMIO`: registro financeiro do valor a pagar pelo seguro.

## Modelo relacional

O modelo usa relacionamentos simples e robustos:
- uma `APOLICE` pertence a um `CLIENTE` e a um `PRODUTO`
- uma `APOLICE` pode gerar um ou mais `CERTIFICADOS`
- uma `APOLICE` pode ter múltiplas `COBERTURAS`
- uma `APOLICE` pode ter vários `RISCOS` associados
- um `SINISTRO` está vinculado a uma `APOLICE` e pode envolver uma ou mais `COBERTURAS`
- um `PREMIO` é gerado para cada apólice e registra vencimentos, valores e pagamento

## Regras de negócio principais

- Cada apólice deve referenciar um produto e um cliente.
- Um produto define a categoria de seguro e pode ter coberturas padrão.
- Certificados formalizam períodos de vigência dentro da apólice.
- Coberturas podem ter limites e franquias específicos por apólice.
- Riscos influenciam na precificação e podem ser marcados como aceitos ou rejeitados.
- Sinistros podem ter diferentes situações, como aberto, em análise, indenizado e negado.
- Prêmios podem ser parcelados e vinculados a diferentes datas de vencimento.

## Exemplo de uso

1. Registrar o cliente e o produto de seguro.
2. Criar a apólice com datas de início e término.
3. Adicionar coberturas e riscos à apólice.
4. Emitir certificado para documentar a vigência.
5. Calcular e gerar o prêmio da apólice.
6. Registrar sinistro e relacionar a cobertura afetada.
7. Atualizar o valor indenizado e o status do sinistro.

## Benefícios do modelo

- Simplicidade: atende operações básicas e mantém os principais relacionamentos.
- Flexibilidade: permite diferentes tipos de produto e adaptação a regras de negócio.
- Transparência: separa apólice, certificado e sinistros de forma clara.
- Evolução: suporta expansão para novos produtos e funcionalidades adicionais.
