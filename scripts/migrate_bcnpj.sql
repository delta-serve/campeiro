-- =============================================================================
-- Migração: bcadastros_cnpj (5 tabelas)
-- De: MergeTree() → Para: ReplacingMergeTree(rev) + ORDER BY corrigido
-- IMPORTANTE: Parar o Bento ANTES de executar este script
-- =============================================================================


-- =============================================================================
-- TABELA 1: CNPJ MATRIZ
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO} TO ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_old;

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
  timestamp_received DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY cnpj
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_old;

SELECT 'matriz_old' as tabela, count() as total FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_old
UNION ALL
SELECT 'matriz_new' as tabela, count() as total FROM ${BCADASTROS_CNPJ_MATRIZ_HISTORICO};


-- =============================================================================
-- TABELA 2: CNPJ SÓCIOS
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO} TO ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_old;

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
  timestamp_received DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY (cnpj, cnpjCpfSocio)
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_old;

SELECT 'socios_old' as tabela, count() as total FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_old
UNION ALL
SELECT 'socios_new' as tabela, count() as total FROM ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO};


-- =============================================================================
-- TABELA 3: CNPJ ESTABELECIMENTO
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO} TO ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_old;

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
  timestamp_received DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY cnpj
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_old;

SELECT 'estab_old' as tabela, count() as total FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_old
UNION ALL
SELECT 'estab_new' as tabela, count() as total FROM ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO};


-- =============================================================================
-- TABELA 4: CNPJ SUCESSÃO
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO} TO ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_old;

CREATE TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}
(
  _id String,
  deleted Bool,
  seq String,
  rev UInt16,
  cnpjSucedida String,
  id String,
  sucessoes String,
  timestamp_received DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY cnpjSucedida
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_old;

SELECT 'sucessao_old' as tabela, count() as total FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_old
UNION ALL
SELECT 'sucessao_new' as tabela, count() as total FROM ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO};


-- =============================================================================
-- TABELA 5: CNPJ DESCONHECIDO
-- =============================================================================

RENAME TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO} TO ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_old;

CREATE TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}
(
  _id String,
  deleted Bool,
  seq String,
  rev UInt16,
  doc String,
  timestamp_received DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY _id
PARTITION BY toYYYYMM(timestamp_received)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

INSERT INTO ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}
SELECT * FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_old;

SELECT 'desconhecido_old' as tabela, count() as total FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_old
UNION ALL
SELECT 'desconhecido_new' as tabela, count() as total FROM ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO};


-- =============================================================================
-- VALIDAÇÃO FINAL: Comparar todas as tabelas
-- =============================================================================
-- Execute após confirmar que todos os counts batem:
--
-- DROP TABLE ${BCADASTROS_CNPJ_MATRIZ_HISTORICO}_old;
-- DROP TABLE ${BCADASTROS_CNPJ_MATRIZ_SOCIOS_HISTORICO}_old;
-- DROP TABLE ${BCADASTROS_CNPJ_ESTABELECIMENTO_HISTORICO}_old;
-- DROP TABLE ${BCADASTROS_CNPJ_SUCESSAO_HISTORICO}_old;
-- DROP TABLE ${BCADASTROS_CNPJ_DESCONHECIDO_HISTORICO}_old;
