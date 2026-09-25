# Especificação de Arquitetura Técnica — Sistema de Assistência Técnica em Clipper

Data: 2026-09-25  
Contexto: loja de assistência técnica de eletrodomésticos e produtos eletrônicos, operação familiar, ambiente MS-DOS em PC Intel 386, sem rede, sem internet e sem integração fiscal.

## 1. Visão geral

A solução proposta é um sistema monousuário desenvolvido em Clipper para operar em ambiente MS-DOS, com banco de dados em arquivos DBF e índices xBase, interface textual em tela cheia e processamento local. O objetivo principal é automatizar o controle operacional da assistência técnica sem depender de infraestrutura sofisticada, sem exigir múltiplos usuários simultâneos e sem introduzir complexidade desnecessária.

A arquitetura deve priorizar:

- confiabilidade em operação local;
- simplicidade de uso por atendentes sem treinamento avançado;
- recuperação após falha de energia ou encerramento inadequado;
- manutenção fácil por equipe local;
- impressão em matricial e relatórios operacionais;
- baixo consumo de memória e disco.

## 2. Premissas e restrições do ambiente

### 2.1 Ambiente operacional

- Sistema operacional: MS-DOS 5.x / 6.x.
- Hardware: PC Intel 386 ou superior.
- Memória: 4 MB a 8 MB, dependendo da configuração.
- Armazenamento: disco rígido local, com backup em disquete.
- Impressão: matricial em porta paralela ou serial.
- Usuário final: microempresa familiar, pouca especialização em TI.

### 2.2 Restrições da solução

- Não há rede local, internet ou acesso remoto.
- Não existe banco de dados relacional e nem engine transacional completo.
- Não pode depender de sistemas externos para funcionamento diário.
- O processo fiscal continua manual e não integrado.
- A consistência dos dados exige disciplina de gravação e rotina de backup.

## 3. Objetivo da arquitetura

A arquitetura em Clipper deve ser pensada como uma aplicação local de processamento transacional, com camadas bem definidas:

1. Interface de usuário em menus e tela de cadastro.
2. Camada de regras de negócio em bibliotecas e rotinas.
3. Camada de acesso a dados com DBF + índices.
4. Camada de relatórios e impressão.
5. Camada de administração e manutenção.

A abordagem não deve ser orientada a serviços ou a múltiplas camadas distribuídas. A estrutura deve ser compacta, direta e estável, adequada ao contexto de 1994.

## 4. Estilo arquitetural

### 4.1 Arquitetura recomendada

- Monolítica local.
- Aplicação stand-alone.
- Base de dados orientada a arquivos xBase.
- Interface textual em modo console.
- Rotinas de negócio centralizadas em módulos.
- Operação por teclado com validações em tempo de execução.

### 4.2 Justificativa

Clipper é apropriado para esta solução porque oferece:

- desenvolvimento rápido para aplicações comerciais;
- gestão eficiente de arquivos DBF e índices;
- geração de relatórios e impressão direta;
- baixo consumo de recursos;
- ampla familiaridade em aplicações de 1990/1994;
- facilidade de manutenção por programadores locais.

O uso de Clipper é tecnicamente coerente com as necessidades de uma loja pequena, onde o problema não é processamento em grande escala, mas organização da operação e controle dos dados.

## 5. Estrutura da aplicação

A aplicação deve ser organizada em módulos funcionais, cada um responsável por um conjunto de telas e regras de negócio.

### 5.1 Módulos principais

1. Menu principal
   - cadastro
   - recepção
   - oficina
   - estoque
   - relatórios
   - administração
   - segurança e usuários

2. Módulo de cadastro
   - clientes
   - aparelhos
   - peças
   - fornecedores
   - status e parâmetros

3. Módulo de operação
   - abertura de ordem de serviço
   - consulta por cliente, telefone e número de série
   - avaliação e diagnóstico
   - orçamento e aprovação
   - execução de reparo
   - entrega e encerramento

4. Módulo de estoque
   - entrada de peças
   - saída por ordem de serviço
   - ajuste manual
   - inventário periódico
   - controle de mínimo e máximo

5. Módulo de relatórios
   - ordens em aberto
   - ordens em atraso
   - estoque baixo
   - movimentação diária
   - histórico de cliente
   - faturamento operacional

6. Módulo administrativo
   - parâmetros do sistema
   - numeração de ordens
   - fechamento diário
   - backup e restauração
   - reindexação
   - manutenção de arquivos

## 6. Arquitetura lógica

### 6.1 Camadas lógicas

#### Camada 1 — Interface do usuário

Responsável pela tela, menus, leitura de campos, mensagens e validações visuais.

Tecnologias e padrões:

- telas em Clipper utilizando @... SAY / GET;
- menus de teclado e combinações de função;
- telas de consulta e manutenção com filtros por prefixo;
- mensagens objetivas em português;
- hotkeys e teclas de função padronizadas.

Exemplos:

- F1 = ajuda
- F2 = busca
- F3 = salvar
- F4 = cancelar
- Esc = sair

#### Camada 2 — Regras de negócio

Responsável pela validação do processo operacional, como:

- impedir ordem com cliente inexistente;
- impedir baixa de material sem quantidade válida;
- bloquear alteração de ordem entregue;
- validar status da ordem ao mudar de fase;
- impedir ajuste de estoque sem autorização;
- calcular valor total do orçamento e do serviço.

Essas regras devem ser implementadas em rotinas reutilizáveis e chamadas por vários módulos, como:

- u_cliente.prg
- u_ordem.prg
- u_estoque.prg
- u_relatorio.prg
- u_backup.prg

#### Camada 3 — Acesso a dados

Responsável pela leitura, gravação, atualização e consultas nos arquivos DBF.

Padrão:

- arquivos DBF para dados transacionais
- índices .NTX ou .MDX, conforme disponibilidade
- buscas por código, nome, telefone, número de série e número de ordem
- uso de funções de acesso centralizadas em bibliotecas

Exemplo de biblioteca:

- db_clientes.prg
- db_estoque.prg
- db_ordens.prg
- db_parametros.prg

#### Camada 4 — Relatórios e impressão

Responsável por documentos e listas impressas.

Documentos-chave:

- recibo de recebimento do aparelho;
- orçamento interno;
- ordem de serviço;
- recibo de entrega;
- listagem por status;
- estoque mínimo;
- movimento de estoque diário;
- fechamento do dia.

#### Camada 5 — Administração e continuidade

Responsável por backup, restauração, reindexação, fechamento e manutenção.

## 7. Modelo de dados

A base de dados deve seguir um modelo simples de arquivos indexados por chaves operacionais.

### 7.1 Arquivos principais

- CLIENTES.DBF
  - codigo
  - nome
  - endereco
  - bairro
  - telefone
  - observacoes
  - status

- APARELHOS.DBF
  - codigo
  - cliente_codigo
  - tipo
  - marca
  - modelo
  - numero_serie
  - acessorios
  - observacoes

- ORDENS.DBF
  - numero
  - cliente_codigo
  - aparelho_codigo
  - data_entrada
  - data_prevista
  - data_entrega
  - status
  - defeito_relato
  - defeito_diagnosticado
  - valor_orcamento
  - valor_total
  - garantia
  - operador
  - observacoes

- ITENS_ORDEM.DBF
  - numero_ordem
  - item_tipo
  - codigo_item
  - descricao
  - quantidade
  - valor_unitario
  - valor_total
  - data

- PECAS.DBF
  - codigo
  - descricao
  - unidade
  - custo
  - preco_venda
  - estoque_atual
  - estoque_minimo
  - localizacao
  - status

- MOVESTOQUE.DBF
  - codigo
  - data
  - tipo_movimento
  - codigo_peca
  - quantidade
  - valor_unitario
  - numero_ordem
  - operador
  - observacao

- PARAMETROS.DBF
  - chave
  - valor
  - descricao

- USUARIOS.DBF
  - codigo
  - nome
  - login
  - senha
  - nivel
  - status

### 7.2 Índices recomendados

- CLIENTES: por código, nome e telefone
- APARELHOS: por código, cliente e número de série
- ORDENS: por número, cliente, status e data
- PECAS: por código, descrição e nível de estoque
- MOVESTOQUE: por data, peça e ordem

Os índices devem permitir:

- localizar cliente por nome parcial;
- localizar cliente por telefone;
- localizar aparelho por número de série;
- localizar ordem por número ou por status;
- consultar peças baixas em estoque.

## 8. Regras de integridade e consistência

Como MS-DOS não fornece transações de banco robustas, a consistência deve ser garantida por regras de aplicação e por convenções de arquivamento.

### 8.1 Regras principais

- A ordem só pode ser salva após validação do cliente e do aparelho.
- A baixa de estoque deve estar vinculada a uma ordem válida.
- Nenhuma peça pode ser removida fisicamente; o registro deve ser marcado como inativo ou cancelado.
- A exclusão de cliente ou peça deve ser substituída por inativação.
- O histórico da ordem deve ser preservado mesmo após entrega.
- Qualquer alteração relevante deve registrar operador, data e motivo.

### 8.2 Salvar e confirmar

A aplicação deve seguir o padrão:

1. validar dados da tela;
2. gravar registro em arquivo temporário;
3. fazer validação de consistência;
4. renomear ou substituir o arquivo principal;
5. atualizar índices;
6. registrar movimentação de rotina;
7. retornar ao menu com confirmação visual.

### 8.3 Recuperação de falhas

Se a aplicação for interrompida durante gravação:

- o arquivo temporário não deve ser confundido com o principal;
- os índices devem poder ser reconstruídos;
- o sistema deve possuir rotina de verificação e reindexação;
- o processo de backup deve ser executado ao final do dia.

## 9. Arquitetura funcional por domínio

### 9.1 Cadastro

Objetivo: manter informações básicas do cliente, do aparelho e das peças.

Fluxo:

- incluir cliente
- incluir aparelho vinculado ao cliente
- consultar cliente por nome ou telefone
- consultar aparelho por número de série
- incluir ou atualizar peça
- controlar status de cliente e peça

### 9.2 Recepção

Objetivo: registrar a entrada do aparelho e documentar a solicitação do cliente.

Processo:

- localizar cliente
- localizar ou cadastrar aparelho
- abrir ordem de serviço
- imprimir recibo de entrada
- registrar defeito relatado
- definir prazo estimado

### 9.3 Diagnóstico e orçamento

Objetivo: avaliar o problema e definir o custo do serviço.

Processo:

- registrar diagnóstico técnico
- listar peças necessárias
- calcular custo de peças + mão de obra
- registrar aprovação ou recusa do cliente
- alterar status da ordem

### 9.4 Oficina

Objetivo: controlar a execução do reparo.

Processo:

- registrar operação executada
- consumir peças do estoque
- atualizar tempo de execução
- registrar observações
- controlar status da ordem até pronta

### 9.5 Entrega

Objetivo: concluir o atendimento e fechar a ordem.

Processo:

- verificar condições finais do reparo
- imprimir recibo de entrega
- registrar garantia
- atualizar data de retirada
- fechar ordem e manter histórico

### 9.6 Estoque

Objetivo: controlar itens físicos e sua reposição.

Processo:

- entrada de peça por compra ou ajuste
- saída por uso em ordem
- baixa por devolução ou consumo inválido
- ajuste manual com autorização
- relatório de itens abaixo do mínimo

## 10. Lógica de persistência em Clipper

### 10.1 Arquivos de dados

A aplicação deve usar arquivos xBase no formato DBF, com a organização abaixo:

- cada tabela com chave primária e índices secundários;
- campos de texto com tamanho fixo e compatível com uso de tela;
- campos numéricos sem excesso de precisão;
- campos de data em formato padronizado.

### 10.2 Convenções de campos

- data: AAAAMMDD ou DD/MM/AAAA, conforme padronização interna;
- valores monetários: em centavos ou em decimal fixo;
- quantidade: inteiro ou decimal com precisão baixa;
- status: código numérico ou texto fixo;
- operadores: código do usuário autenticado.

### 10.3 Controle de transação

Como a linguagem não oferece um mecanismo de transação completo, a aplicação deve implementar uma rotina de escrita em duas etapas:

1. geração de arquivo temporário de trabalho;
2. confirmação do registro com substituição do principal e atualização dos índices.

Em caso de falha:

- manter o arquivo principal íntegro;
- usar arquivo de backup ou cópia temporária para reconstrução;
- permitir restauração consultando os arquivos de trabalho.

## 11. Tratamento de interface e usabilidade

### 11.1 Padrões de interface

- menus em tela inteira;
- operações em português;
- validação de campos em tempo real;
- mensagens claras de erro e confirmação;
- busca por prefixo e tecla de atalho;
- revisão de dados antes de salvar.

### 11.2 Experiência do usuário

- atendente consegue incluir cliente e abrir ordem sem consultar manual;
- campos são organizados na ordem do fluxo real do atendimento;
- telas de consulta e alteração repetem o mesmo padrão;
- relatórios são legíveis em impressora matricial.

## 12. Segurança e permissões

A aplicação terá níveis simples de acesso:

- atendente
- operador de estoque
- supervisor
- administrador

### 12.1 Permissões

- Atendente: cadastrar cliente, abrir ordem, alterar dados básicos.
- Operador de estoque: controlar entradas e saídas, ajustar quantidade.
- Supervisor: liberar orçamentos e fechar ordens.
- Administrador: alterar parâmetros, reindexar arquivos, restaurar backups.

### 12.2 Boas práticas da época

- senha em arquivo separado e protegida por acesso restrito;
- uso de login por operador;
- registro do responsável em cada operação sensível;
- confirmação antes de alterar valores ou fechar rotina diária.

## 13. Relatórios e documentos impressos

A geração de documentos deve ser feita em modo de texto em linha, compatível com matricial.

### 13.1 Relatórios operacionais

- ordem de serviço interna;
- comprovante de recebimento;
- orçamento sem valor fiscal;
- recibo de entrega;
- lista de ordens por status;
- lista de peças abaixo do mínimo;
- movimentação de estoque;
- fechamento do dia.

### 13.2 Requisitos de impressão

- cabeçalho da assistência técnica;
- endereço e telefone;
- nome do cliente e do aparelho;
- número da ordem e data;
- campos legíveis e sem excesso de formatação;
- impressão em papel contínuo ou folha padronizada.

## 14. Backup, restauração e continuidade

A continuidade operacional depende de um processo simples e rígido.

### 14.1 Backup diário

- cópia dos arquivos principais em disquete ou mídia alternada;
- backup em duas cópias em dias alternados;
- guarda de uma cópia fora do computador;
- identificação da mídia com data e conteúdo;
- rotina automática de backup após fechamento diário.

### 14.2 Restauração

- cópia de segurança dos arquivos atuais antes de restaurar;
- confirmação de operador responsável;
- reconstrução de índices após restauração;
- validação da integridade antes de liberar uso.

### 14.3 Procedimentos de contingência

- possibilidade de registrar ordens em livro de contingência caso o computador falhe;
- posterior lançamento do material em sistema;
- controle de rotina manual para evitar perda de operação.

## 15. Estrutura de diretórios da aplicação

A estrutura de arquivos no disco deve ser simples e previsível.

- C:\ASSIST\BIN\
  - executáveis da aplicação
  - bibliotecas e módulos
- C:\ASSIST\DATA\
  - arquivos DBF e índices
- C:\ASSIST\TMP\
  - arquivos temporários
- C:\ASSIST\REL\
  - relatórios gerados
- C:\ASSIST\BACKUP\
  - cópias de segurança
- C:\ASSIST\DOC\
  - manual e instruções

## 16. Módulos de software previstos

A aplicação deve ser dividida em módulos claramente identificados:

- MENU.PRG — menu principal
- CAD_CLIENTE.PRG — cadastro de clientes
- CAD_APARELHO.PRG — cadastro de aparelhos
- CAD_PECA.PRG — cadastro de peças
- ORD_ABERTURA.PRG — abertura de ordem
- ORD_CONSULTA.PRG — consulta e alteração de ordens
- ORD_ORCAMENTO.PRG — orçamento e aprovação
- ORD_REPARO.PRG — execução do serviço
- ESTOQUE.PRG — movimentações e ajustes
- REL_GERAL.PRG — relatórios
- ADMIN.PRG — parâmetros, backup e restauração
- FUNCOES.PRG — bibliotecas utilitárias
- VALIDACAO.PRG — validação de campos e regras
- IMPRESSAO.PRG — geração de documentos

## 17. Exemplo de fluxo principal

### Fluxo de atendimento

1. Atendente acessa menu principal.
2. Localiza ou cadastra cliente.
3. Localiza ou cadastra aparelho.
4. Abre ordem de serviço.
5. Registra defeito e data de entrada.
6. Emite recibo de recebimento.
7. Diagnóstico e aprovação do orçamento.
8. Reserva ou baixa a peça quando necessária.
9. Executa o conserto e atualiza status.
10. Registra entrega e fecha ordem.
11. Emite recibo de entrega e garantia.
12. Realiza fechamento diário e backup.

## 18. Critérios de aceitação da arquitetura

A arquitetura será considerada adequada se atender aos seguintes critérios:

- Operar em MS-DOS sem infraestrutura adicional.
- Manipular clientes, aparelhos, ordens, peças e estoque com arquivos locais.
- Permitir pesquisa rápida por número de ordem, telefone e número de série.
- Gerar documentos impressos sem depender de rede ou web.
- Proteger dados contra perda parcial com backup e rotina de recuperação.
- Acompanhar o fluxo completo da assistência técnica.
- Ser operável por uma pessoa sem elevado conhecimento técnico.
- Ser facilmente mantida por programador local familiar com Clipper.

## 19. Riscos técnicos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Falha de energia durante gravação | perda parcial de dados | arquivos temporários, backup e reindexação |
| Corrupção de índice | falhas de busca | rotina de reconstrução e validação |
| Uso indevido de estoque | divergência física | movimentação vinculada à ordem e autorização |
| Acesso não autorizado | alteração indevida | níveis de usuário e senha |
| Limite de disco | paralisia de operação | controle de capacidade e backup regular |
| Interface complicada | baixa adoção | menus consistentes e telas simples |
| Dependência de um único desenvolvedor | risco de manutenção | documentação, módulos organizados e fontes bem estruturados |

## 20. Recomendação final de implementação

A arquitetura mais correta para a loja de assistência técnica em 1994 é uma aplicação Clipper monousuária, orientada a menus, baseada em arquivos DBF com índices e tarefas operacionais localizadas em módulos funcionais. Essa abordagem oferece equilíbrio entre simplicidade, custo, confiabilidade e rapidez de desenvolvimento.

A solução deve ser construída como um sistema industrial simples e robusto, com foco em:

- gestão do cliente;
- controle do aparelho;
- acompanhamento da ordem de serviço;
- controle de estoque;
- impressões operacionais;
- backup e recuperação.

Não há necessidade de arquitetura distribuída, internet ou banco cliente-servidor. O valor real da solução está em reduzir perda de controle, aumentar a disciplina operacional e preservar a consistência dos dados em um ambiente limitado por tecnologia e custo.

## 21. Conclusão

A arquitetura técnica em Clipper para esta assistência deve ser enxuta, local, estável e orientada à operação real da loja. O sistema deve funcionar como um utilitário de negócio digital, substituindo fichas e cadernos sem exigir infraestrutura complexa. A combinação de arquivos indexados, rotinas de negócio bem separadas, interface textual clara e backup disciplinado oferece a melhor relação custo-benefício para o cenário proposto.
