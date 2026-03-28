-- Script de criação da tabela de Pessoa Física (CPF) no ClickHouse
--
-- Tabela de histórico CDC: preserva todas as revisões CouchDB por CPF.
-- ReplacingMergeTree(dh_extracao) com ORDER BY (cpf, rev) garante:
--   - Cada revisão (rev) é uma linha distinta → histórico real
--   - Reprocessamentos do mesmo (cpf, rev) são deduplicados → idempotência
--   - Skipping index minmax em dh_extracao → queries por período eficientes
--
-- Uso:
-- clickhouse-client --host <host> --port <port> --user <user> --password <password> < scripts/create_table_bcpf.sql

CREATE TABLE IF NOT EXISTS ${CLICKHOUSE_DATABASE}.bcpf_historico
(
    -- IDENTIFICAÇÃO
    cpf String,
    nome_contribuinte String DEFAULT '',
    nome_mae String DEFAULT '',

    -- DADOS PESSOAIS
    dt_nasc String DEFAULT '',
    cod_sexo UInt8 DEFAULT 0,
    ano_obito String DEFAULT '',
    dt_inscricao String DEFAULT '',
    dt_ult_atualiz String DEFAULT '',
    ano_exerc String DEFAULT '',
    cod_sit_cad UInt8 DEFAULT 0,

    -- NATURALIDADE
    cod_mun_nat UInt16 DEFAULT 0,
    uf_mun_nat LowCardinality(String) DEFAULT '',
    cod_nat_ocup UInt16 DEFAULT 0,

    -- ENDEREÇO
    tipo_logradouro LowCardinality(String) DEFAULT '',
    logradouro String DEFAULT '',
    nro_logradouro String DEFAULT '',
    complemento String DEFAULT '',
    bairro String DEFAULT '',
    cep String DEFAULT '',
    cod_mun_domic UInt16 DEFAULT 0,
    uf_mun_domic LowCardinality(String) DEFAULT '',

    -- CONTATO
    telefone String DEFAULT '',
    email String DEFAULT '',

    -- OCUPAÇÃO
    cod_ocup UInt16 DEFAULT 0,

    -- INDICADORES
    ind_estrangeiro UInt8 DEFAULT 0,
    ind_res_ext UInt8 DEFAULT 0,

    -- METADADOS CDC
    seq String DEFAULT '',
    rev UInt16 DEFAULT 0,

    -- TIMESTAMPS
    dh_extracao DateTime,

    -- ÍNDICES
    INDEX idx_dh_extracao dh_extracao TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(dh_extracao)
ORDER BY (cpf, rev)
PARTITION BY toYYYYMM(dh_extracao)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;
