-- =============================================================================
-- Migração: bcadastros_cpf_historico
-- De: MergeTree() + Nullable → Para: ReplacingMergeTree(rev) + DEFAULT
-- IMPORTANTE: Parar o Bento ANTES de executar este script
-- =============================================================================

-- 1. Renomear tabela atual (operação de metadado, instantânea)
RENAME TABLE ${BCADASTROS_CPF_HISTORICO} TO ${BCADASTROS_CPF_HISTORICO}_old;

-- 2. Criar nova tabela com estrutura corrigida
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
  dh_extracao DateTime
)
ENGINE = ReplacingMergeTree(rev)
ORDER BY cpf
PARTITION BY toYYYYMM(dh_extracao)
SETTINGS storage_policy = 'ds3_cold',
 index_granularity = 8192;

-- 3. Copiar dados convertendo Nullable → DEFAULT
INSERT INTO ${BCADASTROS_CPF_HISTORICO}
SELECT
    cpf,
    ifNull(nome_contribuinte, ''),
    ifNull(nome_mae, ''),
    ifNull(dt_nasc, ''),
    ifNull(cod_sexo, 0),
    ifNull(ano_obito, ''),
    ifNull(dt_inscricao, ''),
    ifNull(dt_ult_atualiz, ''),
    ifNull(ano_exerc, ''),
    ifNull(cod_sit_cad, 0),
    ifNull(cod_mun_nat, 0),
    ifNull(uf_mun_nat, ''),
    ifNull(cod_nat_ocup, 0),
    ifNull(tipo_logradouro, ''),
    ifNull(logradouro, ''),
    ifNull(nro_logradouro, ''),
    ifNull(complemento, ''),
    ifNull(bairro, ''),
    ifNull(cep, ''),
    ifNull(cod_mun_domic, 0),
    ifNull(uf_mun_domic, ''),
    ifNull(telefone, ''),
    ifNull(email, ''),
    ifNull(cod_ocup, 0),
    ifNull(ind_estrangeiro, 0),
    ifNull(ind_res_ext, 0),
    ifNull(seq, ''),
    rev,
    dh_extracao
FROM ${BCADASTROS_CPF_HISTORICO}_old;

-- 4. Validar contagem
SELECT 'old' as tabela, count() as total FROM ${BCADASTROS_CPF_HISTORICO}_old
UNION ALL
SELECT 'new' as tabela, count() as total FROM ${BCADASTROS_CPF_HISTORICO};

-- 5. (Opcional) Forçar deduplicação imediata — custoso em tabelas grandes
-- OPTIMIZE TABLE ${BCADASTROS_CPF_HISTORICO} FINAL;

-- 6. Validar após dedup
-- SELECT 'new_dedup' as tabela, count() as total FROM ${BCADASTROS_CPF_HISTORICO};

-- 7. Quando satisfeito com a migração, dropar a tabela antiga
-- DROP TABLE ${BCADASTROS_CPF_HISTORICO}_old;
