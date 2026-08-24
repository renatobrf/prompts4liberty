-- ============================================================================
-- DDL - Sistema de Assistência Técnica em Eletrodomésticos (Repair One)
-- Banco de dados relacional compatível com projeto MS-DOS 1994
-- ============================================================================
-- Data: 2026-08-24
-- Contexto: Aplicação monousuária, autossuficiente, sem internet
-- Objetivo: Persistência de dados em formato SQL moderno, facilita futura migração
-- ============================================================================

-- ============================================================================
-- TABELA: PARAMETRO
-- Descrição: Configurações centralizadas do sistema (numeração, valores padrão, impressão)
-- ============================================================================
CREATE TABLE PARAMETRO (
    id INT PRIMARY KEY,
    proximo_numero_ordem INT NOT NULL DEFAULT 1,
    config_impressora VARCHAR(100),
    configuracao NVARCHAR(MAX),
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operador_atualizacao VARCHAR(50)
);

-- ============================================================================
-- TABELA: CLIENTE
-- Descrição: Cadastro de clientes e informações de contato
-- ============================================================================
CREATE TABLE CLIENTE (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(120) NOT NULL,
    endereco VARCHAR(200),
    telefone VARCHAR(20),
    observacoes NVARCHAR(MAX),
    status VARCHAR(20) DEFAULT 'ATIVO',  -- ATIVO, INATIVO, CANCELADO
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operador_cadastro VARCHAR(50),
    operador_atualizacao VARCHAR(50),
    
    INDEX idx_nome (nome),
    INDEX idx_telefone (telefone),
    INDEX idx_codigo (codigo),
    INDEX idx_status (status)
);

-- ============================================================================
-- TABELA: APARELHO
-- Descrição: Cadastro de aparelhos/equipamentos dos clientes
-- ============================================================================
CREATE TABLE APARELHO (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    cliente_id INT NOT NULL,
    tipo VARCHAR(50) NOT NULL,  -- Geladeira, Fogão, Máquina de Lavar, etc.
    marca VARCHAR(50),
    modelo VARCHAR(50),
    numero_serie VARCHAR(50),
    estado_conservacao VARCHAR(50),  -- Ótimo, Bom, Desgastado, Ruim
    observacoes NVARCHAR(MAX),
    status VARCHAR(20) DEFAULT 'ATIVO',
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operador_cadastro VARCHAR(50),
    operador_atualizacao VARCHAR(50),
    
    FOREIGN KEY (cliente_id) REFERENCES CLIENTE(id),
    INDEX idx_cliente (cliente_id),
    INDEX idx_numero_serie (numero_serie),
    INDEX idx_tipo (tipo)
);

-- ============================================================================
-- TABELA: ORDEM_SERVICO
-- Descrição: Ordens de serviço (núcleo operacional do sistema)
-- ============================================================================
CREATE TABLE ORDEM_SERVICO (
    id INT PRIMARY KEY AUTO_INCREMENT,
    numero INT NOT NULL UNIQUE,
    cliente_id INT NOT NULL,
    aparelho_id INT,
    data_abertura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_prevista_entrega DATE,
    data_encerramento DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'ABERTA',  
    -- ABERTA, EM_DIAGNOSTICO, AGUARDANDO_APROVACAO, AGUARDANDO_PECA, EM_REPARO, PRONTA, ENTREGUE, CANCELADA
    
    -- Defeito e diagnóstico
    defeito_informado NVARCHAR(MAX),
    diagnostico NVARCHAR(MAX),
    
    -- Orçamento
    valor_orcado DECIMAL(10,2),
    data_aprovacao_orcamento DATE,
    aprovado CHAR(1) DEFAULT 'N',  -- S ou N
    
    -- Execução
    valor_final DECIMAL(10,2),
    valor_recebido DECIMAL(10,2),
    data_recebimento DATE,
    forma_pagamento VARCHAR(50),  -- Manual (conforme doc), Dinheiro, Cheque, etc.
    
    -- Garantia
    garantia_dias INT,
    data_vencimento_garantia DATE,
    
    -- Rastreabilidade
    operador_abertura VARCHAR(50),
    operador_fechamento VARCHAR(50),
    observacoes NVARCHAR(MAX),
    
    FOREIGN KEY (cliente_id) REFERENCES CLIENTE(id),
    FOREIGN KEY (aparelho_id) REFERENCES APARELHO(id),
    INDEX idx_numero (numero),
    INDEX idx_cliente (cliente_id),
    INDEX idx_status (status),
    INDEX idx_data_abertura (data_abertura),
    INDEX idx_aparelho (aparelho_id)
);

-- ============================================================================
-- TABELA: ITEM_ORDEM
-- Descrição: Itens de serviço ou peças consumidas em cada ordem
-- ============================================================================
CREATE TABLE ITEM_ORDEM (
    id INT PRIMARY KEY AUTO_INCREMENT,
    ordem_servico_id INT NOT NULL,
    tipo_item VARCHAR(20) NOT NULL,  -- PECA ou SERVICO
    descricao VARCHAR(200),
    quantidade DECIMAL(10,3),
    unidade VARCHAR(20),
    preco_unitario DECIMAL(10,2),
    valor_total DECIMAL(10,2),
    
    data_inclusao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operador_inclusao VARCHAR(50),
    
    FOREIGN KEY (ordem_servico_id) REFERENCES ORDEM_SERVICO(id),
    INDEX idx_ordem (ordem_servico_id),
    INDEX idx_tipo (tipo_item)
);

-- ============================================================================
-- TABELA: PECA
-- Descrição: Cadastro de peças e materiais para reposição/estoque
-- ============================================================================
CREATE TABLE PECA (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    descricao VARCHAR(200) NOT NULL,
    unidade VARCHAR(20) NOT NULL,  -- UN, KG, M, etc.
    custo_unitario DECIMAL(10,2),
    preco_venda DECIMAL(10,2),
    quantidade_atual DECIMAL(10,3),
    estoque_minimo DECIMAL(10,3),
    localizacao VARCHAR(50),  -- Localização física no almoxarifado
    status VARCHAR(20) DEFAULT 'ATIVO',
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operador_cadastro VARCHAR(50),
    observacoes NVARCHAR(MAX),
    
    INDEX idx_codigo (codigo),
    INDEX idx_descricao (descricao),
    INDEX idx_estoque_minimo (quantidade_atual, estoque_minimo)
);

-- ============================================================================
-- TABELA: MOV_ESTOQUE
-- Descrição: Movimentação de peças (nunca apagar, manter rastreabilidade)
-- ============================================================================
CREATE TABLE MOV_ESTOQUE (
    id INT PRIMARY KEY AUTO_INCREMENT,
    peca_id INT NOT NULL,
    data_movimento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_movimento VARCHAR(30) NOT NULL,  -- ENTRADA, SAIDA, AJUSTE, ESTORNO, INVENTARIO
    quantidade DECIMAL(10,3),
    ordem_servico_id INT,  -- Referência à ordem se aplicável
    descricao NVARCHAR(MAX),
    operador VARCHAR(50) NOT NULL,
    data_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (peca_id) REFERENCES PECA(id),
    FOREIGN KEY (ordem_servico_id) REFERENCES ORDEM_SERVICO(id),
    INDEX idx_peca (peca_id),
    INDEX idx_data (data_movimento),
    INDEX idx_tipo (tipo_movimento),
    INDEX idx_ordem (ordem_servico_id)
);

-- ============================================================================
-- TABELA: FORNECEDOR
-- Descrição: Cadastro de fornecedores de peças (não obrigatório na Fase 1)
-- ============================================================================
CREATE TABLE FORNECEDOR (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(120) NOT NULL,
    endereco VARCHAR(200),
    telefone VARCHAR(20),
    email VARCHAR(100),
    pessoa_contato VARCHAR(100),
    prazo_entrega INT,  -- dias
    status VARCHAR(20) DEFAULT 'ATIVO',
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacoes NVARCHAR(MAX),
    
    INDEX idx_nome (nome),
    INDEX idx_codigo (codigo)
);

-- ============================================================================
-- TABELA: USUARIO
-- Descrição: Usuários do sistema (atendente, administrador, técnico)
-- ============================================================================
CREATE TABLE USUARIO (
    id INT PRIMARY KEY AUTO_INCREMENT,
    login VARCHAR(50) NOT NULL UNIQUE,
    nome VARCHAR(100) NOT NULL,
    senha_hash VARCHAR(255),  -- Hash seguro (compatível com aplicação)
    tipo_usuario VARCHAR(50) NOT NULL,  -- ATENDENTE, TECNICO, ADMINISTRADOR
    permissao_preco CHAR(1) DEFAULT 'N',  -- Alterar preço
    permissao_ajuste_estoque CHAR(1) DEFAULT 'N',  -- Ajustar estoque
    permissao_exclusao CHAR(1) DEFAULT 'N',  -- Excluir/cancelar registros
    permissao_restauracao CHAR(1) DEFAULT 'N',  -- Restaurar backup
    status VARCHAR(20) DEFAULT 'ATIVO',
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_ultimo_acesso TIMESTAMP,
    
    INDEX idx_login (login),
    INDEX idx_tipo (tipo_usuario)
);

-- ============================================================================
-- TABELA: LOG_AUDITORIA
-- Descrição: Registro de operações sensíveis (segurança e rastreabilidade)
-- ============================================================================
CREATE TABLE LOG_AUDITORIA (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario_id INT,
    tabela_afetada VARCHAR(50),
    id_registro INT,
    tipo_operacao VARCHAR(20),  -- INSERT, UPDATE, DELETE
    descricao NVARCHAR(MAX),
    valor_anterior NVARCHAR(MAX),
    valor_novo NVARCHAR(MAX),
    data_operacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    endereco_ip VARCHAR(50),
    
    FOREIGN KEY (usuario_id) REFERENCES USUARIO(id),
    INDEX idx_data (data_operacao),
    INDEX idx_usuario (usuario_id),
    INDEX idx_tabela (tabela_afetada)
);

-- ============================================================================
-- TABELA: BACKUP_HISTORICO
-- Descrição: Controle de backups realizados
-- ============================================================================
CREATE TABLE BACKUP_HISTORICO (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data_backup TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_backup VARCHAR(20),  -- DIARIO, SEMANAL, MENSAL
    localizacao_midia VARCHAR(200),  -- Disquete A:, Unidade X:, etc.
    descricao NVARCHAR(MAX),
    tamanho_bytes INT,
    validacao_restauracao CHAR(1),  -- S ou N
    data_validacao TIMESTAMP,
    operador VARCHAR(50),
    observacoes NVARCHAR(MAX),
    
    INDEX idx_data (data_backup),
    INDEX idx_tipo (tipo_backup)
);

-- ============================================================================
-- TABELA: SESSAO_TRABALHO
-- Descrição: Registra aberturas/fechamentos de trabalho diário
-- ============================================================================
CREATE TABLE SESSAO_TRABALHO (
    id INT PRIMARY KEY AUTO_INCREMENT,
    usuario_id INT NOT NULL,
    data_abertura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_fechamento TIMESTAMP,
    numero_ordens_processadas INT DEFAULT 0,
    valor_faturado DECIMAL(10,2),
    observacoes NVARCHAR(MAX),
    
    FOREIGN KEY (usuario_id) REFERENCES USUARIO(id),
    INDEX idx_usuario (usuario_id),
    INDEX idx_data (data_abertura)
);

-- ============================================================================
-- ÍNDICES ADICIONAIS PARA PERFORMANCE
-- ============================================================================

-- Índice composto para pesquisas frequentes
CREATE INDEX idx_ordem_cliente_status ON ORDEM_SERVICO(cliente_id, status);
CREATE INDEX idx_aparelho_cliente_tipo ON APARELHO(cliente_id, tipo);
CREATE INDEX idx_mov_peca_data ON MOV_ESTOQUE(peca_id, data_movimento);

-- ============================================================================
-- VIEWS ÚTEIS PARA RELATÓRIOS
-- ============================================================================

-- View: Ordens em atraso
CREATE VIEW vw_ordens_atraso AS
SELECT 
    o.numero,
    c.nome AS cliente,
    a.tipo AS tipo_aparelho,
    o.status,
    o.data_abertura,
    o.data_prevista_entrega,
    DATEDIFF(DAY, o.data_prevista_entrega, CAST(GETDATE() AS DATE)) AS dias_atraso
FROM ORDEM_SERVICO o
JOIN CLIENTE c ON o.cliente_id = c.id
LEFT JOIN APARELHO a ON o.aparelho_id = a.id
WHERE o.status NOT IN ('ENTREGUE', 'CANCELADA')
  AND o.data_prevista_entrega < CAST(GETDATE() AS DATE);

-- View: Peças abaixo do estoque mínimo
CREATE VIEW vw_pecas_estoque_baixo AS
SELECT 
    id,
    codigo,
    descricao,
    quantidade_atual,
    estoque_minimo,
    (estoque_minimo - quantidade_atual) AS falta,
    localizacao
FROM PECA
WHERE status = 'ATIVO'
  AND quantidade_atual < estoque_minimo
ORDER BY falta DESC;

-- View: Faturamento do dia
CREATE VIEW vw_faturamento_diario AS
SELECT 
    CAST(GETDATE() AS DATE) AS data,
    COUNT(DISTINCT o.id) AS quantidade_ordens,
    SUM(o.valor_final) AS total_faturado,
    AVG(o.valor_final) AS ticket_medio
FROM ORDEM_SERVICO o
WHERE CAST(o.data_encerramento AS DATE) = CAST(GETDATE() AS DATE)
  AND o.status = 'ENTREGUE';

-- View: Histórico de cliente
CREATE VIEW vw_historico_cliente AS
SELECT 
    c.codigo,
    c.nome,
    c.telefone,
    COUNT(o.id) AS total_ordens,
    SUM(o.valor_final) AS valor_total_gasto,
    MAX(o.data_abertura) AS ultima_visita,
    COUNT(CASE WHEN o.status IN ('ABERTA', 'EM_DIAGNOSTICO', 'EM_REPARO') THEN 1 END) AS ordens_abertas
FROM CLIENTE c
LEFT JOIN ORDEM_SERVICO o ON c.id = o.cliente_id
WHERE c.status = 'ATIVO'
GROUP BY c.id, c.codigo, c.nome, c.telefone;

-- ============================================================================
-- DADOS INICIAIS (PARÂMETROS E USUÁRIOS)
-- ============================================================================

-- Inserir parâmetros padrão
INSERT INTO PARAMETRO (id, proximo_numero_ordem, config_impressora, configuracao) 
VALUES (1, 1, 'LPT1:', 'Aplicação Monousuária - Assistência Técnica em Eletrodomésticos');

-- Inserir usuário administrador padrão (MUDAR SENHA NA PRIMEIRA EXECUÇÃO)
INSERT INTO USUARIO (login, nome, senha_hash, tipo_usuario, permissao_preco, permissao_ajuste_estoque, permissao_exclusao, permissao_restauracao, status)
VALUES ('admin', 'Administrador', 'admin123', 'ADMINISTRADOR', 'S', 'S', 'S', 'S', 'ATIVO');

-- ============================================================================
-- FIM DO DDL
-- ============================================================================
-- Notas de implementação:
-- 1. Nunca apagar registros: usar status = 'INATIVO' ou 'CANCELADO'
-- 2. Toda operação sensível deve registrar operador e timestamp
-- 3. MOV_ESTOQUE é auditoria: inserts apenas, nunca updates
-- 4. Backup diário deve incluir toda a base de dados
-- 5. Implementar validação de integridade na aplicação
-- 6. Performance: usar índices conforme volume crescer
-- ============================================================================
