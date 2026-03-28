-- =============================================================================
-- Migração v2: Historização CDC
-- De: ReplacingMergeTree(rev) ORDER BY <chave>
-- Para: ReplacingMergeTree(timestamp) ORDER BY (<chave>, rev)
--
-- Objetivo: Preservar todas as revisões CouchDB como histórico real,
--           deduplicando apenas reprocessamentos do mesmo (chave, rev).
--           Adiciona skipping index minmax para queries por período.
--
-- IMPORTANTE: Parar TODOS os streams Bento ANTES de executar este script.
-- Ordem de execução: seções podem ser executadas independentemente.
-- =============================================================================


-- =============================================================================
-- 1. BCPF: bcadastros.bcpf_historico
-- =============================================================================

-- 1.1 Renomear tabela atual (operação de metadado, instantânea)
RENAME TABLE ${BCADASTROS_CPF_HISTORICO} TO ${BCADASTROS_CPF_HISTORICO}_v1;

-- 1.2 Criar nova tabela com histórico real
CREATE TABLE ${BCADASTROS_CPF_HISTORICO}
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

-- 1.3 Copiar dados (mesmas colunas, sem transformação)
INSERT INTO ${BCADASTROS_CPF_HISTORICO}
SELECT * FROM ${BCADASTROS_CPF_HISTORICO}_v1;

-- 1.4 Materializar o skipping index sobre dados migrados
ALTER TABLE ${BCADASTROS_CPF_HISTORICO} MATERIALIZE INDEX idx_dh_extracao;

-- 1.5 Validar contagem (nova >= antiga é esperado: revs antes deduplicados agora são linhas distintas)
SELECT 'bcpf_v1' AS tabela, count() AS total FROM ${BCADASTROS_CPF_HISTORICO}_v1
UNION ALL
SELECT 'bcpf_v2' AS tabela, count() AS total FROM ${BCADASTROS_CPF_HISTORICO};

-- 1.6 Quando satisfeito, dropar a tabela antiga
-- DROP TABLE ${BCADASTROS_CPF_HISTORICO}_v1;


-- =============================================================================
-- 2. CNPJ MATRIZ: bcadastros.bcnpj_matriz_historico
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO} TO ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_v1;

CREATE TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}
(
  _id String,
  deleted Bool,
  seq String,
  rev UInt16,
  capitalSocial String,
  cnpj String,
  cpfResponsavel String,
  dataInclusaoResponsavel String,
  enteFederativo String,
  naturezaJuridica String,
  nomeEmpresarial String,
  porteEmpresa String,
  qualificacaoResponsavel String,
  timestamp_received DateTime,

  -- ÍNDICES
  INDEX idx_ts_received timestamp_received TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(timestamp_received)
ORDER BY (cnpj, rev)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_v1;

ALTER TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO} MATERIALIZE INDEX idx_ts_received;

SELECT 'cnpj_matriz_v1' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_v1
UNION ALL
SELECT 'cnpj_matriz_v2' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO};

-- DROP TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_v1;


-- =============================================================================
-- 3. CNPJ SÓCIOS: bcadastros.bcnpj_matriz_socios_historico
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO} TO ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_v1;

CREATE TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}
(
  _id String,
  seq String,
  rev UInt16,
  cnpj String,
  cnpjCpfSocio String,
  qualificacaoSocio String,
  dataEntrada String,
  representanteLegal String,
  qualificacaoRepresentanteLegal String,
  nomeSocioEstrangeiro String,
  tipo String,
  pais String,
  timestamp_received DateTime,

  -- ÍNDICES
  INDEX idx_ts_received timestamp_received TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(timestamp_received)
ORDER BY (cnpj, cnpjCpfSocio, rev)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_v1;

ALTER TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO} MATERIALIZE INDEX idx_ts_received;

SELECT 'cnpj_socios_v1' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_v1
UNION ALL
SELECT 'cnpj_socios_v2' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO};

-- DROP TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_v1;


-- =============================================================================
-- 4. CNPJ ESTABELECIMENTO: bcadastros.bcnpj_estabelecimento_historico
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO} TO ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_v1;

CREATE TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}
(
  _id String,
  deleted Bool,
  cnpj String,
  seq String,
  rev UInt16,
  indicadorMatriz String,
  nomeFantasia String,
  situacaoCadastral String,
  motivoSituacao String,
  dataSituacaoCadastral String,
  nomeCidadeExterior String,
  codigoPais String,
  dataInicioAtividade String,
  cnaeFiscal String,
  cnaeSecundarias String,
  tipoLogradouro String,
  logradouro String,
  numero String,
  complemento String,
  bairro String,
  cep String,
  uf String,
  codigoMunicipio String,
  dddTelefone1 String,
  telefone1 String,
  dddTelefone2 String,
  telefone2 String,
  email String,
  situacaoEspecial String,
  dataSituacaoEspecial String,
  tipoOrgaoRegistro String,
  tiposUnidade String,
  formasAtuacao String,
  tipoCrcContadorPF String,
  classificacaoCrcContadorPF String,
  sequencialCrcContadorPF String,
  UfCrcContadorPF String,
  contadorPF String,
  tipoCrcContadorPJ String,
  classificacaoCrcContadorPJ String,
  sequencialCrcContadorPJ String,
  UfCrcContadorPJ String,
  contadorPJ String,
  nire String,
  timestamp_received DateTime,

  -- ÍNDICES
  INDEX idx_ts_received timestamp_received TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(timestamp_received)
ORDER BY (cnpj, rev)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_v1;

ALTER TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO} MATERIALIZE INDEX idx_ts_received;

SELECT 'cnpj_estab_v1' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_v1
UNION ALL
SELECT 'cnpj_estab_v2' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO};

-- DROP TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_v1;


-- =============================================================================
-- 5. CNPJ SUCESSÃO: bcadastros.bcnpj_sucessao_historico
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO} TO ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_v1;

CREATE TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}
(
  _id String,
  deleted Bool,
  seq String,
  rev UInt16,
  cnpjSucedida String,
  id String,
  sucessoes String,
  timestamp_received DateTime,

  -- ÍNDICES
  INDEX idx_ts_received timestamp_received TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(timestamp_received)
ORDER BY (cnpjSucedida, rev)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_v1;

ALTER TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO} MATERIALIZE INDEX idx_ts_received;

SELECT 'cnpj_suces_v1' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_v1
UNION ALL
SELECT 'cnpj_suces_v2' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO};

-- DROP TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_v1;


-- =============================================================================
-- 6. CNPJ DESCONHECIDO: bcadastros.bcnpj_desconhecido_historico
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO} TO ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_v1;

CREATE TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}
(
  _id String,
  deleted Bool,
  seq String,
  rev UInt16,
  doc String,
  timestamp_received DateTime,

  -- ÍNDICES
  INDEX idx_ts_received timestamp_received TYPE minmax GRANULARITY 4
)
ENGINE = ReplacingMergeTree(timestamp_received)
ORDER BY (_id, rev)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold', index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_v1;

ALTER TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO} MATERIALIZE INDEX idx_ts_received;

SELECT 'cnpj_desc_v1' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_v1
UNION ALL
SELECT 'cnpj_desc_v2' AS tabela, count() AS total FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO};

-- DROP TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_v1;
