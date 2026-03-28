# CLAUDE.md — Campeiro

> Este arquivo fornece contexto essencial para agentes de IA (Claude, Copilot, etc.) que trabalham neste repositório. Leia-o antes de qualquer tarefa.

---

## Visão Geral do Projeto

**Campeiro** é uma plataforma de **stream processing e roteamento de mensagens** da Polícia Rodoviária Federal (PRF), desenvolvida pelo Serviço de Soluções de Inteligência.

O nome remete ao tropeiro gaúcho que guia tropas por trilhas e desvios — aqui, cada mensagem é roteada pelo caminho correto com segurança e eficiência.

- **Repositório**: https://github.com/delta-serve/campeiro
- **Organização**: [delta-serve](https://github.com/delta-serve)
- **Origem**: migrado de `git.prf.gov.br/magno.pereira/ds-bento-streams` (GitLab interno PRF)
- **Versão atual**: 2.0.0

---

## Stack Técnica

| Componente | Tecnologia | Versão |
|---|---|---|
| Stream processing | Bento (Redpanda Connect) | 4.x |
| Linguagem de mapeamento | Bloblang | — |
| Cache | Redis | 6+ |
| Monitoramento | Prometheus + Grafana | — |
| Orquestração local | Docker Compose | — |
| Runtime | Linux + systemd | — |

---

## Estrutura de Diretórios

```
campeiro/
├── streams/                  # ⭐ Pipelines Bento — 1 arquivo YAML = 1 stream
│   ├── ab_retorno_renavam.yaml   # RENAVAM: ingestão Kafka → roteamento HTTP
│   ├── bcadastros_bcpf.yaml      # Cadastros CPF: polling HTTP → ClickHouse
│   ├── bcadastros_bcnpj.yaml     # Cadastros CNPJ: polling HTTP → ClickHouse
│   ├── cmv_hickvision.yaml       # Câmeras CMV: Kafka → ClickHouse
│   └── sefaz_bpe.yaml            # Sefaz-MG: BPe (Bilhete de Passagem Eletrônico)
├── config/
│   ├── service.yaml          # Configuração geral (HTTP, logs, métricas)
│   ├── .env.example          # Template de variáveis de ambiente
│   └── resources/
│       └── redis_cache.yaml  # Recurso Redis compartilhado entre streams
├── docker/
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   └── grafana/provisioning/ # Dashboards e datasources auto-provisionados
├── scripts/
│   ├── health_check.sh       # Verificação de saúde do serviço
│   ├── run_with_logs.sh      # Execução com log estruturado
│   └── migrate_*.sql         # Migrações de schema ClickHouse
├── docs/
│   ├── OBSERVABILITY.md      # Guia de métricas e dashboards
│   └── releases/             # Changelogs por versão
├── systemd/
│   └── bento.service.template
├── .opencode/
│   └── agents/               # Agentes especializados para OpenCode
├── certs/                    # Certificados (ignorado pelo git — não versionar)
├── setup.sh                  # Instalação inicial no servidor
└── update.sh                 # Atualização em produção (git pull + restart)
```

---

## Pipelines Existentes

### `ab_retorno_renavam` — RENAVAM / Alerta-Brasil
- **Input**: Kafka (TLS + SASL) — topic configurável via env
- **Processamento**: Bloblang — normalização, enriquecimento, métricas Prometheus customizadas
- **Output**: Múltiplos destinos HTTP (Sentry, Simtrans, Navegantes, SSP/GO) com roteamento condicional por `orgao`/`empresa`
- **Observabilidade**: Métricas de latência por output, master label multi-dimensional

### `bcadastros_bcpf` e `bcadastros_bcnpj` — Cadastros Federais
- **Input**: Polling HTTP com cache Redis (deduplicação)
- **Output**: ClickHouse

### `cmv_hickvision` — Câmeras de Velocidade Média
- **Input**: Kafka
- **Output**: ClickHouse

### `sefaz_bpe` — Bilhete de Passagem Eletrônico
- **Input**: HTTP (Sefaz-MG com certificado mTLS em `certs/`)
- **Output**: ClickHouse

---

## Variáveis de Ambiente

As variáveis são carregadas de `config/.env`. O arquivo `config/.env.example` contém o template.

**Padrão para outputs HTTP:**
```
HTTP_OUTPUT_{DESTINO}_URL         # URL do endpoint
HTTP_OUTPUT_{DESTINO}_BATCH_COUNT # Tamanho do batch (default: 100)
HTTP_OUTPUT_{DESTINO}_BATCH_PERIOD # Período do batch (default: 5s)
HTTP_OUTPUT_{DESTINO}_RETRIES     # Tentativas (default: 3)
HTTP_OUTPUT_{DESTINO}_TIMEOUT     # Timeout (default: 30s)
```

---

## Comandos Importantes

```bash
# Iniciar Bento em modo streams (desenvolvimento)
bento --env-file config/.env \
  -c config/service.yaml \
  -r config/resources/*.yaml \
  streams streams/

# Validar um pipeline
bento --env-file config/.env lint streams/meu_pipeline.yaml

# Validar todos os pipelines
bento --env-file config/.env lint streams streams/*.yaml

# Listar streams ativos
curl -s http://localhost:4195/streams | jq .

# Métricas
curl http://localhost:4195/metrics

# Serviço systemd
sudo systemctl status bento
sudo journalctl -u bento -f

# Atualização em produção
sudo bash update.sh
```

---

## Conventional Commits (obrigatório em português)

```
<tipo>(<escopo>): <descrição curta em português>

<corpo detalhado em português>

Refs: #X  ou  Closes: #X
```

**Tipos:** `feat` | `fix` | `perf` | `refactor` | `docs` | `test` | `chore`

**Escopos:** `pipeline` | `bloblang` | `dashboard` | `docker` | `docs` | `config`

**Exemplos:**
```bash
feat(pipeline): adiciona roteamento SSP/GO no pipeline RENAVAM

Adiciona output Kafka para SSP/GO com condição baseada no campo empresa.

Refs: #12

---

fix(pipeline): corrige perda de mensagens no rebalanceamento Kafka

Adiciona checkpoint manual após batch write.

Closes: #15
```

---

## Agentes OpenCode

Agentes disponíveis em `.opencode/agents/`:

| Agente | Responsabilidade |
|---|---|
| `repo-manager` | Commits, branches, push — Conventional Commits em português |
| `github-manager` | Issues, milestones, labels no GitHub (`delta-serve/campeiro`) |

**Skill disponível:** `bento-bloblang` — usar sempre que trabalhar com pipelines Bento ou mapeamentos Bloblang.

---

## Issues e Rastreamento

- **GitHub Issues**: https://github.com/delta-serve/campeiro/issues
- Labels: `tipo:pipeline`, `tipo:bug`, `tipo:otimizacao`, `tipo:refactor`, `tipo:docs`
- Temas: `tema:renavam`, `tema:bcadastros`, `tema:bpe`, `tema:antt`
- Prioridades: `prioridade:baixa`, `prioridade:média`, `prioridade:alta`, `prioridade:crítica`

---

## Segurança

- `config/.env` — **NUNCA** versionar (está no `.gitignore`)
- `certs/` — **NUNCA** versionar (está no `.gitignore`)
- Certificados mTLS ficam em `certs/` apenas no servidor de produção
- Credenciais sempre via variáveis de ambiente: `${VARIAVEL}`

---

## Contexto Institucional

- **Órgão**: Polícia Rodoviária Federal (PRF)
- **Divisão**: Serviço de Soluções de Inteligência
- **Irmão**: [Garimpeiro](https://github.com/delta-serve/garimpeiro) — extrai dados de portais públicos (mineração)
- **Campeiro**: roteia e processa as mensagens extraídas e de sistemas internos
