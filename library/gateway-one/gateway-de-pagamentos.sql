-- =============================================================================
-- DDL: Gateway de Pagamentos
-- Modelo Relacional — Fato x Transação + Dimensões + Tabelas Operacionais
-- Conformidade: BACEN / SPB / PIX / CNAB 240 / CNAB 400
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SCHEMA
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS gateway;
SET search_path TO gateway;


-- =============================================================================
-- DIMENSÕES
-- Tabelas de referência estável que contextualizam a fato_transacao
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_parceiro
-- Representa bancos, fintechs, varejistas e demais participantes do gateway
-- -----------------------------------------------------------------------------
CREATE TABLE dim_parceiro (
    parceiro_id         SERIAL          PRIMARY KEY,
    codigo_ispb         CHAR(8)         NOT NULL UNIQUE,          -- BACEN ISPB
    nome_razao_social   VARCHAR(200)    NOT NULL,
    nome_fantasia        VARCHAR(100),
    cnpj                CHAR(14)        NOT NULL UNIQUE,
    tipo_parceiro       VARCHAR(30)     NOT NULL                  -- BANCO, FINTECH, VAREJISTA, SUBADQUIRENTE
        CHECK (tipo_parceiro IN ('BANCO', 'FINTECH', 'VAREJISTA', 'SUBADQUIRENTE', 'COOPERATIVA')),
    canal_conectividade VARCHAR(10)     NOT NULL DEFAULT 'API'    -- API, VAN, SFTP
        CHECK (canal_conectividade IN ('API', 'VAN', 'SFTP')),
    ativo               BOOLEAN         NOT NULL DEFAULT TRUE,
    criado_em           TIMESTAMP       NOT NULL DEFAULT NOW(),
    atualizado_em       TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- dim_meio_pagamento
-- Catálogo dos instrumentos de pagamento suportados pelo gateway
-- -----------------------------------------------------------------------------
CREATE TABLE dim_meio_pagamento (
    meio_pagamento_id   SERIAL          PRIMARY KEY,
    codigo              VARCHAR(20)     NOT NULL UNIQUE,
    descricao           VARCHAR(60)     NOT NULL,
    modalidade          VARCHAR(20)     NOT NULL
        CHECK (modalidade IN ('CREDITO', 'DEBITO', 'BOLETO', 'PIX', 'TED', 'DOC')),
    rede_processamento  VARCHAR(30),                              -- VISA, MASTERCARD, ELO, SPB
    prazo_liquidacao_d  SMALLINT        NOT NULL DEFAULT 0,       -- D+0, D+1, D+2
    permite_parcelamento BOOLEAN        NOT NULL DEFAULT FALSE,
    ativo               BOOLEAN         NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- dim_status_transacao
-- Ciclo de vida de uma transação — mapeado ao fluxo do Hiker
-- -----------------------------------------------------------------------------
CREATE TABLE dim_status_transacao (
    status_id           SERIAL          PRIMARY KEY,
    codigo              VARCHAR(30)     NOT NULL UNIQUE,
    descricao           VARCHAR(100)    NOT NULL,
    fase                VARCHAR(20)     NOT NULL
        CHECK (fase IN ('RECEPCAO', 'VALIDACAO', 'PROCESSAMENTO', 'LIQUIDACAO', 'ENCERRAMENTO')),
    terminal            BOOLEAN         NOT NULL DEFAULT FALSE    -- TRUE = status final (não muda mais)
);

INSERT INTO dim_status_transacao (codigo, descricao, fase, terminal) VALUES
    ('RECEBIDA',           'Transação recebida pelo gateway',               'RECEPCAO',       FALSE),
    ('EM_VALIDACAO',       'Em validação estrutural/financeira pelo Hiker', 'VALIDACAO',      FALSE),
    ('VALIDACAO_ERRO',     'Rejeitada na etapa de validação',               'VALIDACAO',      TRUE),
    ('AGUARDANDO_CARGA',   'Aprovada pelo Hiker, aguardando bulk load',     'PROCESSAMENTO',  FALSE),
    ('EM_PROCESSAMENTO',   'Carregada no pipeline de bulk files',           'PROCESSAMENTO',  FALSE),
    ('ENVIADA_ADQUIRENTE', 'Enviada à rede adquirente/SPB',                 'PROCESSAMENTO',  FALSE),
    ('AUTORIZADA',         'Autorizada pela rede',                          'LIQUIDACAO',     FALSE),
    ('LIQUIDADA',          'Liquidação financeira confirmada',              'LIQUIDACAO',     TRUE),
    ('NEGADA',             'Negada pela rede adquirente/SPB',               'ENCERRAMENTO',   TRUE),
    ('CANCELADA',          'Cancelada pelo parceiro ou operador',           'ENCERRAMENTO',   TRUE),
    ('ESTORNADA',          'Estorno realizado com sucesso',                 'ENCERRAMENTO',   TRUE),
    ('PENDENTE_REVISAO',   'Retida para revisão manual (compliance)',       'VALIDACAO',      FALSE);

-- -----------------------------------------------------------------------------
-- dim_canal_origem
-- Canal pelo qual a transação ou arquivo entrou no gateway
-- -----------------------------------------------------------------------------
CREATE TABLE dim_canal_origem (
    canal_id            SERIAL          PRIMARY KEY,
    codigo              VARCHAR(20)     NOT NULL UNIQUE,
    descricao           VARCHAR(60)     NOT NULL,
    tipo                VARCHAR(10)     NOT NULL
        CHECK (tipo IN ('API', 'VAN', 'SFTP', 'DASHBOARD'))
);

INSERT INTO dim_canal_origem (codigo, descricao, tipo) VALUES
    ('API_REST',    'Integração via API REST',              'API'),
    ('VAN_FEBRABAN', 'VAN Febraban — troca de arquivos',   'VAN'),
    ('SFTP_REMESSA', 'Remessa via SFTP',                   'SFTP'),
    ('SFTP_RETORNO', 'Retorno via SFTP',                   'SFTP'),
    ('DASHBOARD',    'Operação manual via dashboard',      'DASHBOARD');

-- -----------------------------------------------------------------------------
-- dim_tempo
-- Dimensão calendário para análises OLAP e dashboards operacionais
-- -----------------------------------------------------------------------------
CREATE TABLE dim_tempo (
    tempo_id            INTEGER         PRIMARY KEY,              -- formato YYYYMMDD
    data                DATE            NOT NULL UNIQUE,
    ano                 SMALLINT        NOT NULL,
    trimestre           SMALLINT        NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes                 SMALLINT        NOT NULL CHECK (mes BETWEEN 1 AND 12),
    semana_ano          SMALLINT        NOT NULL,
    dia_mes             SMALLINT        NOT NULL,
    dia_semana          SMALLINT        NOT NULL,                 -- 1=Dom ... 7=Sab
    nome_mes            VARCHAR(15)     NOT NULL,
    dia_util            BOOLEAN         NOT NULL DEFAULT TRUE,
    feriado_nacional    BOOLEAN         NOT NULL DEFAULT FALSE,
    descricao_feriado   VARCHAR(60)
);


-- =============================================================================
-- TABELAS OPERACIONAIS
-- Entidades que suportam o ciclo operacional do gateway
-- =============================================================================

-- -----------------------------------------------------------------------------
-- arquivo_financeiro
-- Representa um arquivo recebido via VAN/SFTP e processado pelo Hiker
-- -----------------------------------------------------------------------------
CREATE TABLE arquivo_financeiro (
    arquivo_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    parceiro_id         INTEGER         NOT NULL REFERENCES dim_parceiro(parceiro_id),
    canal_id            INTEGER         NOT NULL REFERENCES dim_canal_origem(canal_id),
    nome_arquivo        VARCHAR(255)    NOT NULL,
    layout              VARCHAR(20)     NOT NULL
        CHECK (layout IN ('CNAB240', 'CNAB400', 'XML_BACEN', 'JSON_PIX', 'TXT_VAN')),
    tipo_arquivo        VARCHAR(20)     NOT NULL
        CHECK (tipo_arquivo IN ('REMESSA', 'RETORNO', 'EXTRATO', 'POSICAO', 'CONCILIACAO')),
    tamanho_bytes       BIGINT,
    hash_sha256         CHAR(64),
    quantidade_registros INTEGER,
    valor_total         DECIMAL(18,2),
    status_hiker        VARCHAR(30)     NOT NULL DEFAULT 'RECEBIDO'
        CHECK (status_hiker IN ('RECEBIDO', 'EM_VALIDACAO', 'APROVADO', 'REJEITADO', 'PENDENTE_REVISAO', 'CARREGADO')),
    recebido_em         TIMESTAMP       NOT NULL DEFAULT NOW(),
    processado_em       TIMESTAMP,
    mensagem_erro       TEXT
);

-- -----------------------------------------------------------------------------
-- hiker_auditoria
-- Log detalhado de cada passo de travessia do Hiker sobre um arquivo
-- -----------------------------------------------------------------------------
CREATE TABLE hiker_auditoria (
    auditoria_id        BIGSERIAL       PRIMARY KEY,
    arquivo_id          UUID            NOT NULL REFERENCES arquivo_financeiro(arquivo_id),
    passo               SMALLINT        NOT NULL,                 -- 1..4 conforme fluxo
    descricao_passo     VARCHAR(60)     NOT NULL,
    status_passo        VARCHAR(20)     NOT NULL
        CHECK (status_passo IN ('OK', 'AVISO', 'ERRO', 'CRITICO')),
    registros_lidos     INTEGER,
    erros_encontrados   INTEGER         DEFAULT 0,
    avisos_encontrados  INTEGER         DEFAULT 0,
    detalhe_json        JSONB,                                    -- contexto acumulado do Hiker
    executado_em        TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- conta_participante
-- Conta bancária/chave PIX de pagadores e beneficiários
-- -----------------------------------------------------------------------------
CREATE TABLE conta_participante (
    conta_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    parceiro_id         INTEGER         REFERENCES dim_parceiro(parceiro_id),
    tipo_participante   VARCHAR(15)     NOT NULL
        CHECK (tipo_participante IN ('PAGADOR', 'BENEFICIARIO', 'AMBOS')),
    tipo_conta          VARCHAR(15)     NOT NULL
        CHECK (tipo_conta IN ('CORRENTE', 'POUPANCA', 'PAGAMENTO', 'PIX')),
    ispb_banco          CHAR(8),
    agencia             VARCHAR(5),
    numero_conta        VARCHAR(20),
    chave_pix           VARCHAR(77),                             -- CPF/CNPJ/EMAIL/TELEFONE/EVP
    tipo_chave_pix      VARCHAR(10)
        CHECK (tipo_chave_pix IN ('CPF', 'CNPJ', 'EMAIL', 'TELEFONE', 'EVP')),
    documento           VARCHAR(14)     NOT NULL,                -- CPF ou CNPJ sem formatação
    nome_titular        VARCHAR(200)    NOT NULL,
    ativo               BOOLEAN         NOT NULL DEFAULT TRUE,
    criado_em           TIMESTAMP       NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- FATO CENTRAL
-- fato_transacao — granularidade: uma linha por operação financeira
-- =============================================================================

CREATE TABLE fato_transacao (
    -- Chave surrogate
    transacao_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Chave de negócio rastreável ao parceiro/rede
    nsu                     VARCHAR(30)     NOT NULL,             -- Número Sequencial Único
    codigo_autorizacao       VARCHAR(20),                         -- retornado pela rede adquirente/SPB
    end_to_end_id           VARCHAR(32)     UNIQUE,               -- PIX: E+ISPB+AAAAMMDD+T+nnnnn
    nosso_numero            VARCHAR(20),                         -- Boleto: identificador no banco

    -- Chaves estrangeiras para dimensões
    parceiro_id             INTEGER         NOT NULL REFERENCES dim_parceiro(parceiro_id),
    meio_pagamento_id       INTEGER         NOT NULL REFERENCES dim_meio_pagamento(meio_pagamento_id),
    status_id               INTEGER         NOT NULL REFERENCES dim_status_transacao(status_id),
    canal_id                INTEGER         NOT NULL REFERENCES dim_canal_origem(canal_id),
    tempo_id                INTEGER         NOT NULL REFERENCES dim_tempo(tempo_id),  -- data da transação

    -- Origem do arquivo (quando oriunda de processamento batch)
    arquivo_id              UUID            REFERENCES arquivo_financeiro(arquivo_id),

    -- Partes envolvidas
    conta_pagador_id        UUID            REFERENCES conta_participante(conta_id),
    conta_beneficiario_id   UUID            REFERENCES conta_participante(conta_id),

    -- Valores financeiros (DECIMAL(18,2) garante precisão monetária)
    valor_bruto             DECIMAL(18,2)   NOT NULL CHECK (valor_bruto > 0),
    valor_taxa_gateway      DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    valor_taxa_rede         DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    valor_liquido           DECIMAL(18,2)   GENERATED ALWAYS AS
                                (valor_bruto - valor_taxa_gateway - valor_taxa_rede) STORED,
    valor_estorno           DECIMAL(18,2)   NOT NULL DEFAULT 0.00,

    -- Parcelamento (cartão de crédito)
    numero_parcelas         SMALLINT        NOT NULL DEFAULT 1 CHECK (numero_parcelas BETWEEN 1 AND 48),
    numero_parcela_atual    SMALLINT        NOT NULL DEFAULT 1,
    valor_parcela           DECIMAL(18,2),

    -- Dados do cartão (tokenizado — nunca PAN em claro)
    token_cartao            VARCHAR(64),                          -- token gerado pelo gateway/rede
    bin_cartao              CHAR(6),                              -- primeiros 6 dígitos
    final_cartao            CHAR(4),                             -- últimos 4 dígitos
    bandeira_cartao         VARCHAR(20),                         -- VISA, MASTERCARD, ELO, HIPERCARD
    modalidade_cartao       VARCHAR(15)
        CHECK (modalidade_cartao IN ('CREDITO', 'DEBITO', 'PRE_PAGO', NULL)),

    -- Datas operacionais
    data_hora_transacao     TIMESTAMP       NOT NULL DEFAULT NOW(),
    data_hora_autorizacao   TIMESTAMP,
    data_vencimento_boleto  DATE,
    data_pagamento_boleto   DATE,
    data_liquidacao         DATE,
    data_hora_estorno       TIMESTAMP,

    -- Compliance e rastreabilidade
    ip_origem               INET,
    device_fingerprint      VARCHAR(128),
    score_antifraude        SMALLINT        CHECK (score_antifraude BETWEEN 0 AND 1000),
    retido_compliance       BOOLEAN         NOT NULL DEFAULT FALSE,
    motivo_retencao         VARCHAR(200),

    -- Controle de conciliação
    conciliada              BOOLEAN         NOT NULL DEFAULT FALSE,
    data_conciliacao        DATE,
    lote_conciliacao        VARCHAR(40),

    -- Metadados
    criado_em               TIMESTAMP       NOT NULL DEFAULT NOW(),
    atualizado_em           TIMESTAMP       NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- TABELAS ADJACENTES DE SUPORTE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- transacao_evento
-- Histórico imutável de mudanças de status de cada transação (event sourcing lite)
-- -----------------------------------------------------------------------------
CREATE TABLE transacao_evento (
    evento_id           BIGSERIAL       PRIMARY KEY,
    transacao_id        UUID            NOT NULL REFERENCES fato_transacao(transacao_id),
    status_anterior_id  INTEGER         REFERENCES dim_status_transacao(status_id),
    status_novo_id      INTEGER         NOT NULL REFERENCES dim_status_transacao(status_id),
    origem_evento       VARCHAR(30)     NOT NULL,                -- HIKER, API, VAN, OPERADOR, REDE
    payload_json        JSONB,
    criado_em           TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- transacao_estorno
-- Detalhe de estornos parciais ou totais vinculados a uma transação original
-- -----------------------------------------------------------------------------
CREATE TABLE transacao_estorno (
    estorno_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    transacao_origem_id UUID            NOT NULL REFERENCES fato_transacao(transacao_id),
    valor_estorno       DECIMAL(18,2)   NOT NULL CHECK (valor_estorno > 0),
    motivo              VARCHAR(200)    NOT NULL,
    tipo_estorno        VARCHAR(15)     NOT NULL
        CHECK (tipo_estorno IN ('TOTAL', 'PARCIAL')),
    codigo_autorizacao  VARCHAR(20),
    solicitado_por      VARCHAR(100),
    solicitado_em       TIMESTAMP       NOT NULL DEFAULT NOW(),
    confirmado_em       TIMESTAMP,
    status              VARCHAR(20)     NOT NULL DEFAULT 'SOLICITADO'
        CHECK (status IN ('SOLICITADO', 'PROCESSANDO', 'CONFIRMADO', 'NEGADO'))
);

-- -----------------------------------------------------------------------------
-- liquidacao_financeira
-- Registro de liquidação D+n — vincula transações ao settlement final
-- -----------------------------------------------------------------------------
CREATE TABLE liquidacao_financeira (
    liquidacao_id       UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    parceiro_id         INTEGER         NOT NULL REFERENCES dim_parceiro(parceiro_id),
    data_liquidacao     DATE            NOT NULL,
    quantidade_transacoes INTEGER       NOT NULL DEFAULT 0,
    valor_bruto_total   DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    valor_taxas_total   DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    valor_liquido_total DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    arquivo_retorno_id  UUID            REFERENCES arquivo_financeiro(arquivo_id),
    status              VARCHAR(20)     NOT NULL DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE', 'PROCESSANDO', 'LIQUIDADO', 'ERRO')),
    criado_em           TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- liquidacao_transacao
-- Associação N:N entre liquidações e transações
-- -----------------------------------------------------------------------------
CREATE TABLE liquidacao_transacao (
    liquidacao_id       UUID            NOT NULL REFERENCES liquidacao_financeira(liquidacao_id),
    transacao_id        UUID            NOT NULL REFERENCES fato_transacao(transacao_id),
    PRIMARY KEY (liquidacao_id, transacao_id)
);

-- -----------------------------------------------------------------------------
-- config_layout_arquivo
-- Centraliza as regras de validação do Hiker por parceiro e layout (configServerFiles)
-- -----------------------------------------------------------------------------
CREATE TABLE config_layout_arquivo (
    config_id           SERIAL          PRIMARY KEY,
    parceiro_id         INTEGER         REFERENCES dim_parceiro(parceiro_id), -- NULL = regra global
    layout              VARCHAR(20)     NOT NULL,
    tipo_arquivo        VARCHAR(20)     NOT NULL,
    versao              VARCHAR(10)     NOT NULL DEFAULT '1.0',
    regras_json         JSONB           NOT NULL,                -- schema de validação do Hiker
    ativo               BOOLEAN         NOT NULL DEFAULT TRUE,
    vigente_desde       DATE            NOT NULL DEFAULT CURRENT_DATE,
    vigente_ate         DATE,
    criado_em           TIMESTAMP       NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- ÍNDICES — performance em consultas operacionais e OLAP
-- =============================================================================

-- fato_transacao
CREATE INDEX idx_fato_transacao_parceiro      ON fato_transacao (parceiro_id);
CREATE INDEX idx_fato_transacao_status        ON fato_transacao (status_id);
CREATE INDEX idx_fato_transacao_tempo         ON fato_transacao (tempo_id);
CREATE INDEX idx_fato_transacao_meio_pgto     ON fato_transacao (meio_pagamento_id);
CREATE INDEX idx_fato_transacao_data_hora     ON fato_transacao (data_hora_transacao);
CREATE INDEX idx_fato_transacao_nsu           ON fato_transacao (nsu);
CREATE INDEX idx_fato_transacao_end_to_end    ON fato_transacao (end_to_end_id) WHERE end_to_end_id IS NOT NULL;
CREATE INDEX idx_fato_transacao_arquivo       ON fato_transacao (arquivo_id)    WHERE arquivo_id IS NOT NULL;
CREATE INDEX idx_fato_transacao_conciliada    ON fato_transacao (conciliada, data_liquidacao);

-- arquivo_financeiro
CREATE INDEX idx_arquivo_parceiro             ON arquivo_financeiro (parceiro_id);
CREATE INDEX idx_arquivo_status_hiker         ON arquivo_financeiro (status_hiker);
CREATE INDEX idx_arquivo_recebido_em          ON arquivo_financeiro (recebido_em);

-- hiker_auditoria
CREATE INDEX idx_hiker_arquivo               ON hiker_auditoria (arquivo_id);

-- transacao_evento
CREATE INDEX idx_evento_transacao            ON transacao_evento (transacao_id);
CREATE INDEX idx_evento_criado_em            ON transacao_evento (criado_em);

-- liquidacao
CREATE INDEX idx_liquidacao_parceiro_data    ON liquidacao_financeira (parceiro_id, data_liquidacao);


-- =============================================================================
-- COMENTÁRIOS DE DOCUMENTAÇÃO
-- =============================================================================

COMMENT ON TABLE fato_transacao         IS 'Tabela fato central. Granularidade: uma operação financeira. Integra cartão, boleto, PIX, TED/DOC.';
COMMENT ON TABLE dim_parceiro           IS 'Dimensão dos participantes do gateway: bancos, fintechs, varejistas.';
COMMENT ON TABLE dim_meio_pagamento     IS 'Dimensão dos instrumentos de pagamento suportados.';
COMMENT ON TABLE dim_status_transacao   IS 'Dimensão do ciclo de vida de uma transação, mapeada ao fluxo do Hiker.';
COMMENT ON TABLE dim_tempo              IS 'Dimensão calendário para análises OLAP no dashboard operacional.';
COMMENT ON TABLE arquivo_financeiro     IS 'Controla arquivos CNAB/PIX/XML recebidos via VAN ou SFTP — insumo do Hiker.';
COMMENT ON TABLE hiker_auditoria        IS 'Log imutável dos passos de travessia do componente Hiker por arquivo.';
COMMENT ON TABLE transacao_evento       IS 'Event log de mudanças de status — rastreabilidade total do ciclo de vida.';
COMMENT ON TABLE liquidacao_financeira  IS 'Agrupamento D+n de transações para liquidação interbancária via SPB.';
COMMENT ON TABLE config_layout_arquivo  IS 'Regras de validação por layout/parceiro consumidas pelo configServerFiles/Hiker.';

COMMENT ON COLUMN fato_transacao.end_to_end_id      IS 'Identificador E2E do PIX conforme padrão BACEN: E+ISPB+AAAAMMDD+T+sequencial.';
COMMENT ON COLUMN fato_transacao.valor_liquido       IS 'Calculado: valor_bruto - taxa_gateway - taxa_rede. Coluna gerada (STORED).';
COMMENT ON COLUMN fato_transacao.token_cartao        IS 'Tokenização PCI-DSS: nunca armazenar PAN em claro nesta tabela.';
COMMENT ON COLUMN fato_transacao.score_antifraude    IS 'Score 0-1000 retornado pelo motor de antifraude. >= 700 = alto risco.';
