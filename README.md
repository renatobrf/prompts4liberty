# Prompts4liberty

Prompts4liberty é um repositório pessoal para compartilhar conhecimento sobre engenharia de prompts, design de serviços e arquitetura de software com exemplos práticos.

## Sobre o projeto

Este projeto reúne documentos e exemplos focados em:
- modelagem de serviços e dados para operações de seguros
- arquitetura de software em AWS para aplicações modernas
- planos de budget e estimativas para nuvem
- scripts e demonstrações de prompt engineering

## Autor

[Renato Barufi](https://www.linkedin.com/in/renato-barufi-a2a7ab130/) — Solutions Architect, cientista da computação e entusiasta de tecnologia.

## Conteúdo principal

### Service design e arquitetura
- `library/insurance-one/servico-seguro-simples.md` — descrição do serviço de seguro simples
- `library/insurance-one/servico-anti-fraude.md` — descrição do serviço anti-fraude para seguros
- `library/insurance-one/software-architecture-insurance-aws-cloud.md` — arquitetura AWS para o serviço de seguros e anti-fraude
- `library/insurance-one/budget-plan-insurance-aws-cloud.md` — plano de budget anual para rodar a solução na AWS

### Modelagem de dados e DDL
- `library/insurance-one/seguro-simples.sql` — DDL relacional para suportar apólices, clientes, produtos, certificados, riscos, sinistros e prêmios

### Prompt engineering
- `library/write-a-prompt.md` — instruções e exemplos de criação de prompts
- `library/book_recommendation.md` — exemplo de prompt para recomendação de livros
- `library/business_coaching.md` — prompt para coaching de negócios
- `library/app_weather.md` — prompt para criar um app de previsão do tempo

### Projetos e experiências
- `pygame-8bits/` e `pygame-16bits/` — exemplos de jogos e material de prompt relacionados a jogos Python
- `source/performance_score.py` — script para avaliação de desempenho local

## Como usar

### Executar o script de performance

```bash
python3 performance_score.py > out.txt
```

> Este projeto é voltado para estudo e documentação. Os arquivos Markdown servem como referência para arquitetar serviços e gerar artefatos de projeto.

## Organização do repositório

- `library/` — conteúdo de prompts e documentos técnicos
- `blog/` — artigos e análises relacionadas a arquitetura e prompts
- `pygame-8bits/` e `pygame-16bits/` — projetos de jogos e prompts de aplicação
- `source/` — scripts utilitários

## Próximos passos

- adicionar exemplos de implementação Node.js para os serviços descritos
- converter os modelos de dados em APIs reais
- incluir automações de infraestrutura como código para AWS
- ampliar a base de prompts com casos de uso reais
