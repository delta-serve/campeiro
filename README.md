# Campeiro

> **Campeiro** — do gaúcho que conhece cada trilha do campo. Aqui, cada mensagem encontra seu caminho.

Plataforma de **stream processing e roteamento de mensagens** usando [Bento (Redpanda Connect)](https://warpstreamlabs.github.io/bento/) em modo streams, permitindo a criação e gerenciamento de múltiplos pipelines de dados isolados em uma única instância.

Parte do ecossistema **[delta-serve](https://github.com/delta-serve)** — Polícia Rodoviária Federal · Serviço de Soluções de Inteligência.

---

## 🗺️ Sobre o Nome

**Campeiro** é o guia das tropas nas grandes campanhas do Sul do Brasil — o homem que conhece cada trilha, cada desvio, cada passagem. Aqui na plataforma, cada mensagem é uma tropa: recebida, triada e enviada pelo caminho certo, com segurança e eficiência.

---

## 🎯 Finalidade

- **Roteamento inteligente**: Encaminha mensagens para os destinos corretos com base em regras de negócio
- **Integração de sistemas**: Conecta fontes heterogêneas (HTTP, Kafka, RabbitMQ, arquivos) a destinos variados (ClickHouse, APIs, filas)
- **Transformação de dados**: Mapeamentos Bloblang para enriquecimento, validação e normalização
- **Observabilidade**: Métricas Prometheus + dashboards Grafana prontos para uso
- **Operação simples**: Deploy via Git pull + restart, sem orquestradores complexos

---

## 🏗️ Stack Técnica

| Componente | Tecnologia |
|---|---|
| Stream processing | [Bento (Redpanda Connect)](https://warpstreamlabs.github.io/bento/) |
| Linguagem de mapeamento | [Bloblang](https://warpstreamlabs.github.io/bento/docs/guides/bloblang/about/) |
| Cache | Redis |
| Monitoramento | Prometheus + Grafana |
| Orquestração local | Docker Compose |
| Runtime | Linux + systemd |

---

## 📁 Estrutura do Projeto

```
campeiro/
├── streams/                  # Pipelines individuais (1 arquivo = 1 stream)
│   ├── ab_retorno_renavam.yaml
│   ├── bcadastros_bcpf.yaml
│   ├── bcadastros_bcnpj.yaml
│   ├── cmv_hickvision.yaml
│   └── sefaz_bpe.yaml
├── config/
│   ├── service.yaml          # Configuração geral (HTTP, logs, métricas)
│   ├── .env.example          # Template de variáveis de ambiente
│   └── resources/
│       └── redis_cache.yaml  # Cache Redis compartilhado
├── docker/
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   └── grafana/
│       └── provisioning/     # Dashboards e datasources
├── scripts/
│   ├── health_check.sh
│   ├── run_with_logs.sh
│   └── migrate_*.sql         # Migrações de schema
├── docs/
│   ├── README.md
│   ├── OBSERVABILITY.md
│   └── releases/             # Notas de versão
├── systemd/
│   └── bento.service.template
├── .opencode/                # Agentes de IA para desenvolvimento
│   └── agents/
├── setup.sh                  # Instalação inicial no servidor
└── update.sh                 # Atualização em produção
```

---

## 🚀 Instalação

### Pré-requisitos

- Linux (Ubuntu 20.04+ ou similar)
- Git
- Acesso sudo
- Redis (opcional, para pipelines com cache)

### Setup inicial

```bash
# 1. Clonar repositório
sudo git clone https://github.com/delta-serve/campeiro.git /opt/campeiro
cd /opt/campeiro

# 2. Configurar variáveis de ambiente
sudo cp config/.env.example config/.env
sudo nano config/.env

# 3. Executar setup (instala Bento, configura systemd)
sudo bash setup.sh

# 4. Verificar status
sudo systemctl status bento
curl http://localhost:4195/ping
```

---

## 💻 Desenvolvimento

### Criar um novo pipeline

```bash
# 1. Criar branch
git checkout -b feature/pipeline-nome-descritivo

# 2. Criar arquivo do stream
nano streams/meu_pipeline.yaml

# 3. Validar sintaxe
bento --env-file config/.env lint streams/meu_pipeline.yaml

# 4. Testar localmente
bento --env-file config/.env \
  -c config/service.yaml \
  -r config/resources/*.yaml \
  streams streams/meu_pipeline.yaml
```

### Estrutura básica de um pipeline

```yaml
input:
  http_server:
    path: /api/meu-endpoint
    label: input_api

pipeline:
  processors:
    - mapping: |
        root = this
        root.processado_em = now()
      label: transform_dados

output:
  stdout:
    codec: lines
    label: output_log
```

### Validar e commitar

```bash
# Validar todos os streams
bento --env-file config/.env lint streams streams/*.yaml

# Commit (Conventional Commits em português)
git commit -m "feat(pipeline): adiciona pipeline meu_pipeline

Descrição do que o pipeline faz.

Refs: #X"
```

---

## 📊 Monitoramento

```bash
# Health check
curl http://localhost:4195/ping

# Listar streams ativos
curl -s http://localhost:4195/streams | jq .

# Métricas Prometheus
curl http://localhost:4195/metrics

# Logs em tempo real
sudo journalctl -u bento -f
```

---

## 🔄 Deploy em Produção

```bash
cd /opt/campeiro
sudo bash update.sh

# Ou manualmente:
sudo git pull origin main
sudo systemctl restart bento
sudo journalctl -u bento -f
```

---

## 🔒 Segurança

- **NUNCA** commite `config/.env` (está no `.gitignore`)
- Use variáveis de ambiente para credenciais: `${REDIS_PASSWORD}`
- Certificados ficam em `certs/` (ignorado pelo git)
- Mantenha permissões: `chmod 600 config/.env`

---

## 📝 Conventional Commits

**Formato obrigatório (português):**

```
<tipo>(<escopo>): <descrição curta>

<corpo detalhado>

Refs: #X
```

| Tipo | Uso |
|---|---|
| `feat` | Novo pipeline ou funcionalidade |
| `fix` | Correção de bug |
| `perf` | Otimização de performance |
| `refactor` | Refatoração sem mudança funcional |
| `docs` | Documentação |
| `chore` | Manutenção (docker, config) |

**Escopos:** `pipeline`, `bloblang`, `dashboard`, `docker`, `docs`, `config`

---

## 📚 Documentação

- [Bento - Documentação oficial](https://warpstreamlabs.github.io/bento/docs/about/)
- [Bloblang - Linguagem de mapeamento](https://warpstreamlabs.github.io/bento/docs/guides/bloblang/about/)
- [Streams Mode](https://warpstreamlabs.github.io/bento/docs/guides/streams_mode/about/)
- [Observabilidade](docs/OBSERVABILITY.md)

---

## 👥 Equipe

**Desenvolvido pelo Serviço de Soluções de Inteligência — Polícia Rodoviária Federal**

| Nome | Email |
|---|---|
| Anderson Fratuci | anderson.fratuci@prf.gov.br |
| Magno Pereira | magno.pereira@prf.gov.br |

---

*© 2025-2026 — Polícia Rodoviária Federal — Serviço de Soluções de Inteligência*
