# Avaliação de Arquitetura — Sistema de Assistência Técnica em MS-DOS

Data da avaliação: 2026-08-21  
Contexto operacional avaliado: 1994

## Visão geral

Este documento avalia a criação de um sistema stand-alone para uma assistência técnica familiar de eletrodomésticos e produtos eletrônicos. O sistema deve operar em um PC Intel 386 com MS-DOS, sem dependência de rede, internet, meios eletrônicos de pagamento ou integração com emissão fiscal.

A solução recomendada é um aplicativo monousuário, orientado a menus e teclado, com banco de dados local baseado em arquivos indexados. O primeiro release deve controlar clientes, aparelhos, ordens de serviço, estoque básico, caixa operacional e relatórios impressos. A prioridade é confiabilidade, simplicidade de operação e recuperação após falhas, e não volume ou integração.

## Escopo

### Incluído

- Cadastro de clientes, endereços e telefones.
- Cadastro de aparelhos, marca, modelo, número de série e acessórios recebidos.
- Abertura, consulta, alteração e encerramento de ordens de serviço.
- Registro de defeito informado, diagnóstico, orçamento, aprovação e execução.
- Controle de peças e materiais consumidos na ordem de serviço.
- Inventário de estoque com entradas, saídas, ajustes e estoque mínimo.
- Pesquisa por cliente, telefone, número de série e número da ordem.
- Impressão de recibo, orçamento, ordem de serviço e relatórios gerenciais.
- Rotina de fechamento diário e cópia de segurança em disquete.

### Fora do escopo

- Integração com cartão, banco, PIX ou qualquer meio eletrônico de pagamento.
- Emissão ou integração automática com notas fiscais.
- Acesso remoto, aplicativo web, e-mail ou internet.
- Concorrência entre vários usuários ou terminais.
- Sincronização automática com contabilidade, fornecedores ou governo.

## Premissas e restrições de 1994

- O computador pode ter memória e disco limitados para os padrões atuais; o programa deve ser pequeno e evitar consumo desnecessário.
- MS-DOS não oferece os serviços de segurança, multitarefa e isolamento encontrados em sistemas operacionais modernos.
- A operação deve continuar mesmo sem rede e sem serviços externos.
- O usuário provavelmente terá conhecimento básico de informática; telas, mensagens e atalhos precisam ser claros em português.
- Impressora matricial deve ser tratada como periférico principal para documentos operacionais.
- Dados podem ser perdidos por desligamento incorreto, falha do disco, corrupção de arquivos ou erro humano.
- A rotina fiscal e financeira continua manual; o sistema deve deixar explícito o que é controle interno e o que é documento fiscal.

## Objetivos de negócio

1. Reduzir o uso de fichas e cadernos para localizar clientes e serviços.
2. Dar visibilidade às ordens abertas, aguardando orçamento, aguardando peça e prontas para entrega.
3. Evitar perda de peças e melhorar a reposição do estoque.
4. Padronizar o atendimento e o acompanhamento do aparelho.
5. Produzir informações simples para decidir compras, cobrança e capacidade de atendimento.

## Avaliação das linguagens

| Opção | Avaliação | Recomendação |
|---|---|---|
| COBOL | Forte para arquivos, registros e relatórios; adequado a aplicações administrativas. Exige uma ferramenta de desenvolvimento e manutenção compatível com MS-DOS. | Boa opção se houver experiência local e compilador disponível. |
| C | Permite executável compacto e bom controle de memória, arquivos e impressora. A equipe precisa disciplinar o acesso aos dados e a interface. | Opção técnica preferencial para um desenvolvimento novo com equipe experiente. |
| C++ | Pode ser usado, mas o custo de complexidade e memória não traz benefício relevante para este escopo. | Evitar no primeiro release. |
| BASIC | Rápido para prototipar e acessível, mas pode oferecer menor robustez, desempenho e facilidade de evolução dependendo do ambiente. | Adequado para protótipo ou equipe sem outra alternativa, com testes rigorosos. |

A decisão deve considerar mais a disponibilidade de profissionais, compilador, bibliotecas de impressão e suporte local do que a linguagem isoladamente. Para esta operação, um sistema bem feito em COBOL é melhor que um sistema em C sem manutenção disponível. Como decisão inicial, recomenda-se **C ou COBOL**, com preferência por COBOL quando o perfil do sistema for predominantemente cadastral e de relatórios.

## Arquitetura proposta

### Estilo

- Aplicação monolítica stand-alone.
- Execução local em MS-DOS.
- Uma base de dados local por instalação.
- Interface textual de tela cheia, com menus, teclas de função e validação de campos.
- Processamento transacional simples: cada inclusão, alteração ou baixa deve ser gravada antes de retornar ao menu.

Não há justificativa para microserviços, banco cliente-servidor, mensageria ou uma API neste cenário. Esses padrões aumentariam dependências e pontos de falha sem resolver uma necessidade existente.

### Componentes funcionais

1. **Cadastro**: clientes, aparelhos, peças, fornecedores e formas de status.
2. **Recepção**: abertura da ordem, identificação do aparelho, acessórios, defeito relatado e previsão.
3. **Oficina**: diagnóstico, mão de obra, peças utilizadas, observações e histórico de alterações.
4. **Orçamento**: cálculo do serviço, peças e desconto; registro de aprovação ou recusa.
5. **Entrega e encerramento**: confirmação do serviço, valor recebido manualmente, garantia e data de retirada.
6. **Estoque**: movimentações vinculadas às ordens e ajustes autorizados.
7. **Relatórios**: ordens por status, serviços em atraso, estoque baixo, faturamento registrado e histórico do cliente.
8. **Administração**: numeração, parâmetros, fechamento e backup/restauração.

### Fluxo principal da ordem de serviço

1. Receber o aparelho e localizar ou cadastrar o cliente.
2. Gerar número sequencial da ordem e imprimir o comprovante de recebimento.
3. Registrar diagnóstico e orçamento.
4. Aguardar aprovação, registrar a decisão e reservar ou baixar peças quando aplicável.
5. Executar o reparo e registrar peças, mão de obra e testes.
6. Marcar como pronta, imprimir aviso ou recibo de entrega e registrar a retirada.
7. Encerrar a ordem preservando seu histórico para consultas futuras.

Os status devem ser controlados por valores predefinidos, por exemplo: `ABERTA`, `EM DIAGNOSTICO`, `AGUARDANDO APROVACAO`, `AGUARDANDO PECA`, `EM REPARO`, `PRONTA`, `ENTREGUE` e `CANCELADA`.

## Modelo de dados lógico

Os arquivos devem ser indexados por chaves que suportem as pesquisas mais frequentes:

- **CLIENTE**: código, nome, endereço, telefone e observações.
- **APARELHO**: código, cliente, tipo, marca, modelo, número de série e estado de conservação.
- **ORDEM_SERVICO**: número, cliente, aparelho, datas, status, defeito, diagnóstico, orçamento, aprovação, garantia e encerramento.
- **ITEM_ORDEM**: ordem, peça ou serviço, quantidade, preço e valor aplicado.
- **PECA**: código, descrição, unidade, custo, preço, quantidade atual, estoque mínimo e localização.
- **MOV_ESTOQUE**: data, peça, tipo de movimento, quantidade, ordem relacionada e operador.
- **PARAMETRO**: próximo número, valores padrão e configurações de impressão.

Cada ordem deve ter um número único. Movimentos de estoque não devem ser apagados; correções devem ser registradas como estorno ou ajuste, mantendo rastreabilidade suficiente para a operação.

## Persistência e integridade

- Usar arquivos de registros fixos ou formato indexado compatível com o compilador escolhido.
- Manter índices para código da ordem, telefone do cliente, nome e número de série.
- Validar campos obrigatórios, datas, valores e referências antes da gravação.
- Gravar primeiro a operação principal e depois seus itens relacionados, com rotina de recuperação para operações interrompidas.
- Evitar exclusão física de clientes, peças e ordens; preferir marcação de inativo ou cancelado.
- Reservar espaço e definir limites operacionais documentados para evitar atingir a capacidade do disco sem aviso.
- Executar uma verificação e reconstrução de índices a partir dos arquivos de dados.

Como MS-DOS não fornece uma transação de banco de dados completa, a aplicação deve ter um diário simples de operação ou arquivos temporários com renomeação ao final da gravação. Isso reduz o risco de deixar um registro parcialmente atualizado após queda de energia.

## Requisitos não funcionais

### Usabilidade

- Operação integral por teclado, com campos na mesma ordem do processo de atendimento.
- Mensagens de erro objetivas e confirmação antes de ações destrutivas.
- Busca incremental ou por prefixo onde for viável.
- Numeração e status visíveis na tela e nos documentos impressos.

### Desempenho

- Abrir menus e consultas comuns em poucos segundos.
- Evitar varreduras completas em pesquisas frequentes; usar índices.
- Gerar relatórios longos em modo de impressão sem bloquear a consistência dos dados.

### Disponibilidade

- O sistema deve funcionar durante todo o expediente sem rede.
- Uma falha do aplicativo não deve inutilizar os arquivos de dados.
- Deve existir um procedimento de reinício, restauração e reindexação que possa ser executado pelo responsável da loja.

### Segurança e controle

- Usuários simples, por exemplo atendente e administrador, com permissões diferentes para preço, exclusão, ajustes de estoque e restauração.
- Senhas armazenadas de forma compatível com a época e protegidas contra visualização casual; não tratar isso como segurança criptográfica moderna.
- Registro de operador e data nas operações sensíveis.
- Bloqueio ou confirmação para alteração de uma ordem entregue e para ajustes de inventário.

## Backup, continuidade e suporte

A cópia de segurança é o requisito operacional mais importante fora do código:

- Fazer backup diário em disquete alternado e guardar ao menos uma cópia fora do computador.
- Fazer uma cópia semanal ou mensal de retenção mais longa.
- Identificar mídia com data e conteúdo, e testar restauração regularmente.
- Nunca sobrescrever a única cópia conhecida.
- Manter disquetes de instalação, versão do programa, parâmetros da impressora e instruções de restauração.
- Definir um livro manual de contingência para registrar ordens quando o computador estiver indisponível e lançar os dados depois.

A restauração deve solicitar confirmação, criar uma cópia dos arquivos atuais e executar reindexação e validação antes de liberar o sistema para uso.

## Impressão e documentos

A primeira versão deve suportar impressora matricial por porta paralela ou serial, com largura configurável. Documentos recomendados:

- comprovante de recebimento do aparelho;
- orçamento sem valor fiscal;
- ordem de serviço interna;
- recibo de entrega e garantia do reparo;
- relação de serviços por status;
- lista de peças abaixo do estoque mínimo;
- movimento de estoque e resumo diário.

Os documentos devem exibir razão social, endereço e telefone da assistência, mas declarar claramente quando forem controles internos ou orçamento, sem se apresentar como nota fiscal.

## Riscos e mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Corrupção do disco ou desligamento durante gravação | Perda de ordens e estoque | Backup alternado, gravação temporária, validação e reindexação |
| Falta de suporte ao compilador | Impossibilidade de corrigir o sistema | Selecionar ferramenta disponível localmente e entregar código-fonte e documentação |
| Interface difícil para atendentes | Baixa adoção e retorno ao papel | Teste com usuários reais, atalhos consistentes e treinamento curto |
| Estoque divergente do físico | Compras erradas e perdas | Movimentos vinculados às ordens, inventário periódico e ajustes autorizados |
| Limite de disco ou quantidade de registros | Parada da operação | Indicadores de capacidade e arquivamento anual planejado |
| Alteração indevida de valores ou ordens | Perda financeira e conflitos | Perfis, confirmação, histórico e fechamento diário |
| Mudança futura de equipamento ou sistema operacional | Custo de migração | Formato de dados documentado, exportação textual e backups legíveis |
| Mistura entre controle interno e obrigação fiscal | Risco administrativo | Escopo explícito e validação com contador local |

## Roadmap de implantação

### Fase 0 — Descoberta

- Observar um dia de atendimento e desenhar o fluxo real.
- Levantar campos usados nas fichas, documentos e controles atuais.
- Confirmar configuração do 386, memória, disco, impressora e ferramenta disponível.
- Definir limites esperados de clientes, ordens e peças.

### Fase 1 — Núcleo operacional

- Entregar clientes, aparelhos, ordens de serviço, status e impressão de recebimento.
- Migrar apenas cadastros confiáveis; não atrasar o início tentando digitalizar todo o histórico.
- Pilotar com atendimento paralelo em papel durante um período curto.

### Fase 2 — Estoque e fechamento

- Adicionar peças, movimentações, consumo por ordem, inventário e relatórios.
- Implementar fechamento diário e rotina de backup/restauração.
- Treinar responsáveis e registrar procedimentos operacionais.

### Fase 3 — Estabilização

- Medir tempo de atendimento, ordens atrasadas, divergência de estoque e falhas de backup.
- Corrigir telas e relatórios com base no uso real.
- Criar exportação em texto ou impressão de dados para futura migração.

## Critérios de aceitação

- Um atendente consegue cadastrar um cliente e abrir uma ordem sem consultar o manual.
- A ordem pode ser localizada por número, telefone e número de série.
- O fluxo de orçamento, aprovação, peças, entrega e garantia preserva o histórico.
- O consumo de uma peça altera o estoque e deixa um movimento identificável.
- O sistema imprime os documentos essenciais na impressora disponível.
- Um backup pode ser criado e restaurado em outro diretório ou mídia de teste.
- Um desligamento durante uma gravação não deixa a base silenciosamente inconsistente.
- O responsável consegue executar fechamento, reindexação e inventário periódico.

## Recomendação final

Prosseguir com um **MVP monousuário para MS-DOS**, implementado em **COBOL ou C conforme a capacidade de suporte disponível**, usando arquivos locais indexados, interface textual e impressão matricial. A arquitetura deve ser deliberadamente modesta: o valor está em organizar a operação e preservar dados, não em antecipar integrações que não existiam em 1994.

Antes do desenvolvimento completo, construir um protótipo de cadastro, abertura de ordem, impressão e backup. Se esse protótipo funcionar com o hardware real e for compreendido pelos atendentes, a solução terá validado os riscos mais importantes. O sistema deve ser entregue com código-fonte, formato de dados documentado, utilitário de backup/restauração e manual operacional curto.
