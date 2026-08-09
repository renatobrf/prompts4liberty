-- Modelo relacional para operação de seguro simples

CREATE TABLE cliente (
    cliente_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(200) NOT NULL,
    tipo_pessoa VARCHAR(20) NOT NULL,
    documento VARCHAR(30) NOT NULL,
    email VARCHAR(150),
    telefone VARCHAR(30),
    endereco VARCHAR(250),
    data_nascimento DATE,
    estado_civil VARCHAR(30),
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produto (
    produto_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    nome VARCHAR(120) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    descricao VARCHAR(500),
    vigencia_dias INTEGER,
    coeficiente_base NUMERIC(12,6),
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE apolice (
    apolice_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero VARCHAR(80) NOT NULL UNIQUE,
    cliente_id BIGINT NOT NULL,
    produto_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    data_inicio_vigencia DATE NOT NULL,
    data_fim_vigencia DATE NOT NULL,
    status VARCHAR(40) NOT NULL,
    valor_seguro NUMERIC(18,2) NOT NULL,
    observacoes VARCHAR(1000),
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_apolice_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(cliente_id),
    CONSTRAINT fk_apolice_produto FOREIGN KEY (produto_id) REFERENCES produto(produto_id)
);

CREATE TABLE certificado (
    certificado_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    apolice_id BIGINT NOT NULL,
    numero VARCHAR(80) NOT NULL UNIQUE,
    data_emissao DATE NOT NULL,
    data_inicio_vigencia DATE NOT NULL,
    data_fim_vigencia DATE NOT NULL,
    status VARCHAR(40) NOT NULL,
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_certificado_apolice FOREIGN KEY (apolice_id) REFERENCES apolice(apolice_id)
);

CREATE TABLE cobertura (
    cobertura_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL UNIQUE,
    nome VARCHAR(150) NOT NULL,
    descricao VARCHAR(500),
    limite NUMERIC(18,2),
    franquia NUMERIC(18,2),
    produto_id BIGINT,
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cobertura_produto FOREIGN KEY (produto_id) REFERENCES produto(produto_id)
);

CREATE TABLE apolice_cobertura (
    apolice_cobertura_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    apolice_id BIGINT NOT NULL,
    cobertura_id BIGINT NOT NULL,
    valor_seguro NUMERIC(18,2),
    limite NUMERIC(18,2),
    franquia NUMERIC(18,2),
    premio_bruto NUMERIC(18,2),
    premio_liquido NUMERIC(18,2),
    CONSTRAINT fk_apolice_cobertura_apolice FOREIGN KEY (apolice_id) REFERENCES apolice(apolice_id),
    CONSTRAINT fk_apolice_cobertura_cobertura FOREIGN KEY (cobertura_id) REFERENCES cobertura(cobertura_id)
);

CREATE TABLE risco (
    risco_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    apolice_id BIGINT NOT NULL,
    tipo_risco VARCHAR(100) NOT NULL,
    descricao VARCHAR(500),
    valor_risco NUMERIC(18,2),
    localizacao VARCHAR(240),
    condicoes_especificas VARCHAR(500),
    status VARCHAR(40) NOT NULL,
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_risco_apolice FOREIGN KEY (apolice_id) REFERENCES apolice(apolice_id)
);

CREATE TABLE sinistro (
    sinistro_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    apolice_id BIGINT NOT NULL,
    numero VARCHAR(80) NOT NULL UNIQUE,
    data_ocorrencia DATE NOT NULL,
    data_comunicacao DATE NOT NULL,
    descricao VARCHAR(1000),
    valor_reclamado NUMERIC(18,2),
    valor_indenizado NUMERIC(18,2),
    status VARCHAR(40) NOT NULL,
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sinistro_apolice FOREIGN KEY (apolice_id) REFERENCES apolice(apolice_id)
);

CREATE TABLE sinistro_cobertura (
    sinistro_cobertura_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sinistro_id BIGINT NOT NULL,
    cobertura_id BIGINT NOT NULL,
    valor_reclamado NUMERIC(18,2),
    valor_indenizado NUMERIC(18,2),
    situacao VARCHAR(40) NOT NULL,
    CONSTRAINT fk_sinistro_cobertura_sinistro FOREIGN KEY (sinistro_id) REFERENCES sinistro(sinistro_id),
    CONSTRAINT fk_sinistro_cobertura_cobertura FOREIGN KEY (cobertura_id) REFERENCES cobertura(cobertura_id)
);

CREATE TABLE premio (
    premio_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    apolice_id BIGINT NOT NULL,
    data_vencimento DATE NOT NULL,
    valor_bruto NUMERIC(18,2) NOT NULL,
    valor_liquido NUMERIC(18,2) NOT NULL,
    taxa NUMERIC(12,6),
    taxa_iof NUMERIC(12,6),
    situacao VARCHAR(40) NOT NULL,
    data_pagamento DATE,
    meio_pagamento VARCHAR(60),
    referencia VARCHAR(120),
    criado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_premio_apolice FOREIGN KEY (apolice_id) REFERENCES apolice(apolice_id)
);

CREATE INDEX idx_apolice_cliente ON apolice(cliente_id);
CREATE INDEX idx_apolice_produto ON apolice(produto_id);
CREATE INDEX idx_certificado_apolice ON certificado(apolice_id);
CREATE INDEX idx_apolice_cobertura_apolice ON apolice_cobertura(apolice_id);
CREATE INDEX idx_risco_apolice ON risco(apolice_id);
CREATE INDEX idx_sinistro_apolice ON sinistro(apolice_id);
CREATE INDEX idx_premio_apolice ON premio(apolice_id);
