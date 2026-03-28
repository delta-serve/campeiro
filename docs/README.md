# Documentação - Pipeline AB Retorno RENAVAM

Documentação técnica do pipeline de processamento de retornos RENAVAM para o sistema Alerta Brasil.

---

## 📖 Guias de Implementação

### Observabilidade
- **[OBSERVABILITY.md](OBSERVABILITY.md)** - Estratégia completa de observabilidade do pipeline
  - Health checks periódicos (logs a cada ~15 minutos)
  - Interpretação de logs e sinais de alerta
  - Comandos de troubleshooting e monitoramento
  - Integração com métricas Prometheus/Grafana
  - Evolução futura e melhorias planejadas

### Operacionais
- **[Implementação SENTRY RabbitMQ](SENTRY_RABBITMQ_IMPLEMENTATION.md)** - Guia completo de configuração, troubleshooting e operação do output RabbitMQ para SENTRY/MULTIWAY
- **[Atualizações Dashboard Grafana](dashboard-updates-summary.md)** - Resumo técnico das alterações no dashboard Grafana (seção RabbitMQ + consolidação)

---

## 📅 Histórico de Releases

Documentação cronológica das versões do pipeline, contendo decisões arquiteturais, implementações técnicas e contexto de negócio.

### v1.x - Integrações Multi-Protocolo

#### [v1.4.0 - Otimização Dashboard Grafana](releases/v1.4.0-dashboard-optimization.md) (Mar 13, 2026)
**Redução de Complexidade Visual**
- Dashboard reduzido de 43 para 29 painéis (-33%)
- Hierarquia clara: 11 painéis visíveis + 3 rows colapsadas
- Novos KPIs: Taxa de Erro % e Health Status (gauge 0-100%)
- Consolidação de outputs (Kafka/HTTP/RabbitMQ lado a lado)
- Grid responsivo e cores consistentes por protocolo

**Decisões-chave:**
- Rows colapsadas para detalhes técnicos (não poluem visão inicial)
- Health Status calculado: `100 - (erro% * 10) - (latência_alta ? 20 : 0)`
- Simplificação de equipamentos: 6 painéis → 1 painel (Top 10)
- Tempo de detecção de problemas: 30s → 3s (10x mais rápido)

---

#### [v1.3.0 - Health Check Logs Periódicos](releases/v1.3.0-observability.md) (Mar 13, 2026)
**Observabilidade Proativa**
- Health check logs estruturados a cada ~15 minutos
- Branch processor não-bloqueante (zero impacto)
- Formato dual: JSON + mensagem legível
- Status de outputs, empresas, protocolos
- Documentação completa de observabilidade

**Decisões-chave:**
- Condição temporal Bloblang (`timestamp_unix() % 900`)
- Sem dependências de resources (compatibilidade Bento 1.10.0)
- Informações qualitativas (status) complementando métricas quantitativas
- Guia operacional dedicado (`docs/OBSERVABILITY.md`)

---

#### [v1.2.0 - SENTRY RabbitMQ](releases/v1.2.0-sentry-rabbitmq.md) (Mar 12, 2026)
**Integração RabbitMQ com SENTRY/MULTIWAY**
- Roteamento por campo `empresa = "MULTIWAY"`
- Configuração AMQP 0.9 com TLS
- Métricas Prometheus customizadas
- Dashboard Grafana com seção dedicada (6 painéis)

**Decisões-chave:**
- Migração de Kafka → RabbitMQ para parceiro SENTRY
- Exchange declaration desabilitada (permissões `write` apenas)
- Persistent messages para garantia de entrega
- Fix erro 403 ACCESS_REFUSED em produção

---

#### [v1.1.0 - Roteamento Avançado](releases/v1.1.0-advanced-routing.md) (Mar 11, 2026)
**Roteamento Inteligente e Métricas Multidimensionais**
- Roteamento por empresa/equipamento via Bloblang
- Métricas Prometheus com 4+ dimensões (orgao, empresa, status, equipamento)
- Dashboard Grafana consolidado (37 painéis)
- Dead Letter Queue (DLQ) para mensagens não roteadas

**Decisões-chave:**
- Campo `destination` calculado via Bloblang
- Switch cases baseados em lógica de negócio
- Métricas granulares para análise detalhada
- Filtros dinâmicos no Grafana (orgão, empresa, status)

---

#### [v1.0.0 - Integração HTTP](releases/v1.0.0-http-integration.md) (Mar 10, 2026)
**Primeira Integração HTTP (PROTENET - Navegantes/SC)**
- Output HTTP substituindo Kafka para parceiro específico
- Retry logic com backoff exponencial
- Circuit breaker para proteção
- Batching: 50 eventos por requisição HTTP
- Timeout configurável (30s)

**Decisões-chave:**
- HTTP POST para webhook do parceiro
- JSON payload com array de eventos
- Métricas de latência (p50, p95, p99)
- Fallback para evitar perda de dados

---

### v0.x - Fundação e Otimização

#### [v0.3.0 - Escala e Arquivamento](releases/v0.3.0-scale-archive.md) (Mar 9, 2026)
**Multi-Destino e Arquivamento S3**
- 4º destino: SSP-NAVEGANTES/SC (Kafka)
- Arquivamento de eventos raw em S3
- Compliance: retenção de 90 dias
- Capacidade de replay para análise forense

**Decisões-chave:**
- Topic separado `eventos` para raw data
- Formato JSON original preservado em metadados
- S3 bucket com lifecycle policy
- Particionamento por data (YYYY/MM/DD)

---

#### [v0.2.0 - Otimização de Performance](releases/v0.2.0-optimization.md) (Fev 27, 2026)
**Redução de Logs e Métricas Críticas**
- Redução de volume de logs: 10GB/dia → 1GB/dia (-90%)
- Structured logging (JSON format)
- Métricas críticas Prometheus
- Dashboard Grafana com 25 painéis

**Decisões-chave:**
- Log level ajustado (INFO → WARN para operações normais)
- Sampling de logs de debug (1%)
- Métricas vs logs: preferir métricas para volume
- Alertas baseados em thresholds

---

#### [v0.1.0 - Fundação](releases/v0.1.0-foundation.md) (Fev 25-26, 2026)
**Arquitetura Base do Pipeline**
- Input: Kafka (Azure Event Hub) - topic `ab-retorno-renavam`
- 3 destinos Kafka iniciais:
  - MAUA-SP (topic: retornos-maua)
  - OSASCO-SP (topic: retornos-osasco)
  - SIMTRANS-VCA-BA (topic: retornos-simtrans)
- Dashboard Grafana inicial (12 painéis)
- Métricas básicas (input, output, erros)

**Decisões-chave:**
- Bento como engine de streaming
- Kafka como protocolo padrão inicial
- Consumer group: `ab-retorno-renavam-cg`
- Batching: 100 mensagens ou 5 segundos

---

## 🏗️ Arquitetura Atual

### Protocolos Suportados
- **Kafka** (Azure Event Hub) - Input + Outputs legados
- **HTTP** - PROTENET (Navegantes-SC)
- **RabbitMQ** - SENTRY/MULTIWAY (Mauá-SP + Osasco-SP)

### Destinos Ativos (4)
| Destino | Órgão(s) | Protocolo | Empresa | Status |
|---------|----------|-----------|---------|--------|
| eventos | (raw data) | Kafka | - | Arquivamento |
| sentry | Mauá-SP, Osasco-SP | RabbitMQ | MULTIWAY | ✅ Ativo |
| navegantes | Navegantes-SC | HTTP | PROTENET | ✅ Ativo |
| simtrans | SIMTRANS-VCA-BA | Kafka | - | ✅ Ativo |

### Métricas Prometheus
- `renavam_messages_received_total` - Input
- `renavam_messages_sent_total{destination}` - Output por destino
- `renavam_rabbitmq_sentry_sent_total` - RabbitMQ específico
- `renavam_http_navegantes_sent_total` - HTTP específico
- `renavam_eventos_raw_sent_total` - Arquivamento
- `renavam_messages_by_*` - Métricas multidimensionais (orgao, empresa, status, equipamento)

### Dashboard Grafana
- **43 painéis** distribuídos em 6 seções
- Refresh: 5 segundos
- Filtros dinâmicos: destino, órgão, status, empresa, equipamento

---

## 🔗 Links Úteis

### Documentação Externa
- [Bento (Redpanda Connect)](https://docs.redpanda.com/redpanda-connect/)
- [Bloblang Language](https://docs.redpanda.com/redpanda-connect/guides/bloblang/about/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/)
- [Prometheus Metrics](https://prometheus.io/docs/concepts/metric_types/)

### Código e Configuração
- [Pipeline Principal](../streams/ab_retorno_renavam.yaml)
- [Variáveis de Ambiente](../config/.env)
- [Dashboard Grafana](../docker/grafana/provisioning/dashboards/02_renavam.json)

### Repositórios
- **GitLab** (código): git.prf.gov.br/magno.pereira/ds-bento-streams
- **GitHub** (gestão): github.com/alerta-brasil/deltaserve (issues/milestones)

---

## 📝 Convenções

### Versionamento
- Seguimos **Semantic Versioning** (SemVer): MAJOR.MINOR.PATCH
- **MAJOR** (1.x.x): Mudanças de arquitetura ou breaking changes
- **MINOR** (x.1.x): Novas funcionalidades (novos destinos, protocolos)
- **PATCH** (x.x.1): Bug fixes e otimizações

### Commits
- Formato: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`
- Scope: `renavam`, `dashboard`, `config`, `docker`

### Branches
- `master` - Produção (protegida)
- `develop` - Desenvolvimento
- `feature/*` - Novas funcionalidades
- `fix/*` - Correções

---

## 🎯 Roadmap

### Próximas Integrações (Planejadas)
- [ ] Adicionar mais órgãos via SENTRY (expandir lista)
- [ ] Integração SIMTRANS via HTTP (migrar de Kafka)
- [ ] Output para banco de dados (PostgreSQL/ClickHouse)
- [ ] Stream processing com janelas temporais

### Melhorias Técnicas
- [ ] Implementar batching no RabbitMQ (via processor archive)
- [ ] Adicionar compressão de payloads (gzip)
- [ ] Circuit breaker configurável por output
- [ ] Alertas Prometheus → Alertmanager
- [ ] Testes automatizados (unit + integration)

---

**Última atualização:** 12 de março de 2026  
**Mantenedor:** Magno Pereira  
**Projeto:** Alerta Brasil - DeltaServe
