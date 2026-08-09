# Arquitetura de Software para Seguro Simples no AWS

## Introdução

Este documento descreve a arquitetura de software para executar a operação de seguro simples na AWS. O foco é suportar a emissão de apólices, certificados, coberturas, riscos, sinistros, prêmios e o serviço de anti-fraude.

## Objetivo

Construir uma solução em nuvem AWS que seja escalável, resiliente, segura e de fácil operação. A arquitetura deve:
- hospedar a API de seguros e o serviço anti-fraude
- armazenar dados relacionais de apólices, clientes, produtos, sinistros e prêmios
- suportar integração com serviços de autenticação, monitoramento e auditoria
- reduzir a manutenção operacional usando serviços gerenciados

## Visão geral da arquitetura

A solução é composta por:
- front-end ou cliente HTTP que consome APIs
- Amazon API Gateway para roteamento e autenticação
- Amazon Cognito para identidade e autorização
- Amazon ECS com Fargate para executar microserviços de seguro e anti-fraude
- Amazon RDS for PostgreSQL para armazenamento relacional principal
- Amazon SQS para orquestração assíncrona e fila de eventos
- Amazon SNS para notificações e alertas
- AWS Secrets Manager para segredos e credenciais
- Amazon CloudWatch para logs, métricas e alarmes
- AWS X-Ray para rastreamento distribuído

## Componentes principais

### 1. Amazon API Gateway

- atua como porta de entrada para as APIs REST/HTTP do serviço de seguros e anti-fraude
- faz roteamento para serviços ECS internos
- integra autenticação JWT via Amazon Cognito
- aplica políticas de CORS, throttling e proteção básica contra ataques

### 2. Amazon Cognito

- gerencia usuários, grupos e provedores de identidade
- emite tokens de acesso para clientes e dashboards de operação
- permite separação de perfis: analistas, atendimento, backoffice e integradores

### 3. Amazon ECS + Fargate

Deploy dos containers para:
- serviço de apólice / contratos
- serviço de sinistros
- serviço de prêmios
- serviço de anti-fraude
- serviço de auditoria / histórico

Cada serviço deve ser executado como task ECS Fargate para reduzir a necessidade de gerenciar clusters de EC2.

### 4. Amazon RDS for PostgreSQL

Base de dados relacional que contém o modelo de dados de seguro simples:
- `cliente`
- `produto`
- `apolice`
- `certificado`
- `cobertura`
- `risco`
- `sinistro`
- `premio`
- tabelas de suporte para anti-fraude

RDS deve ser configurado em Multi-AZ para alta disponibilidade e backups automatizados.

### 5. Amazon SQS e SNS

- SQS para filas de processamento assíncrono de eventos, como geração de prêmios, atualização de sinistros e análise de fraude.
- SNS para notificações de alerta, envio de e-mail/SMS ou integração com sistemas de monitoramento e compliance.

### 6. AWS Secrets Manager

Armazena credenciais de banco de dados, chaves de API e segredos para conexões externas. Os serviços ECS acessam esses segredos em runtime.

### 7. Amazon CloudWatch

- CloudWatch Logs para coletar logs de aplicação e containers
- CloudWatch Metrics para monitorar uso de CPU, memória, latência de endpoints e filas SQS
- CloudWatch Alarms para acionar alertas em incidentes

### 8. AWS X-Ray

Rastreamento distribuído para diagnosticar latência e dependências entre serviços. Fundamental para identificar gargalos em processos de emissão, sinistros e análise de fraude.

## Fluxo de requisições

1. Cliente envia requisição ao API Gateway.
2. API Gateway valida JWT no Amazon Cognito.
3. Requisição roteada ao serviço ECS correspondente.
4. O serviço consulta ou persiste dados no RDS.
5. Eventos assíncronos (ex.: análise de fraude, notificações) publicam mensagens em SQS ou SNS.
6. O serviço anti-fraude consome eventos, avalia regras e pode atualizar o status de apólice/sinistro.
7. Logs e métricas são registrados em CloudWatch; rastreamentos em X-Ray.

## Integração do serviço anti-fraude

O serviço anti-fraude pode ser executado como uma task ECS dedicada ou como uma função Lambda:
- análise em tempo real durante a criação de apólice e sinistro
- ingestão de eventos de fila SQS para revisões assíncronas
- geração de alertas e casos suspeitos via SNS
- armazenamento de resultados e evidências no RDS ou em DynamoDB para consultas rápidas

## Segurança

Recomenda-se:
- usar Amazon Cognito para autenticação e autorização
- restringir acesso à API Gateway por políticas de recurso ou WAF
- habilitar criptografia em trânsito (TLS) e em repouso (RDS, S3, Secrets Manager)
- aplicar políticas IAM de menor privilégio para tasks ECS e serviços AWS
- auditar alterações e acessos usando AWS CloudTrail

## Disponibilidade e resiliência

- RDS em Multi-AZ com failover automático
- ECS Fargate em sub-redes privadas across multiple AZs
- API Gateway com endpoints públicos e integração em múltiplas regiões se necessário
- SQS para desacoplar e absorver picos de carga
- Backup e recuperação de desastre com snapshots do RDS e políticas de retenção

## Observabilidade

- Logs estruturados e centralizados no CloudWatch Logs
- Dashboards CloudWatch para métricas de apólice, sinistro e fraude
- Alarmes para latência alta, erros 5xx e filas SQS altas
- X-Ray para rastrear chamadas entre API Gateway, ECS e RDS

## Infraestrutura como Código

A infraestrutura pode ser provisionada com:
- AWS CDK (TypeScript ou Python)
- Terraform com provider AWS
- CloudFormation para templates gerenciados

## Extensões futuras

Esta arquitetura permite expandir com:
- Amazon Sagemaker para modelos de detecção de fraude mais sofisticados
- Amazon Athena e QuickSight para relatórios e análise de sinistros
- Amazon Elasticache para cache de configurações e dados de produto
- Amazon OpenSearch para busca e análise de logs de sinistros e casos de fraude

## Resumo

A arquitetura proposta usa AWS gerenciado para minimizar a operação e escalar conforme a demanda. O serviço de seguros e o componente de anti-fraude são implementados como containers ECS Fargate, com dados principais no Amazon RDS e integração de filas e notificações via SQS/SNS.
