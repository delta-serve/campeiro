# Observabilidade - Pipeline AB Retorno RENAVAM

## 📊 Visão Geral

Este documento descreve a estratégia completa de observabilidade implementada no pipeline AB Retorno RENAVAM, incluindo health checks periódicos, métricas Prometheus/Grafana e comandos de troubleshooting.

## 🏥 Health Check Logs Periódicos

### Objetivo
Fornecer visibilidade proativa do estado do pipeline através de logs estruturados que aparecem periodicamente, facilitando troubleshooting sem necessidade de polling constante de métricas.

### Características

- **Frequência:** Aproximadamente a cada 15 minutos (900 segundos)
- **Mecanismo:** Bloblang com condição temporal baseada em `timestamp_unix() % 900`
- **Formato:** JSON estruturado + mensagem legível
- **Impacto:** Zero no fluxo de mensagens (branch não-bloqueante)
- **Nível de log:** INFO

### Exemplo de Health Check Log

#### Formato JSON Estruturado
```json
{
  "@service": "bento-streams",
  "@environment": "production",
  "stream": "ab_retorno_renavam",
  "level": "info",
  "time": "2026-03-13T09:15:00-03:00",
  "health_check": {
    "pipeline": "ab_retorno_renavam",
    "timestamp": "2026-03-13 09:15:00",
    "timestamp_unix": 1741867500,
    "outputs": {
      "total": 4,
      "active": [
        "eventos_kafka",
        "sentry_rabbitmq",
        "protenet_http",
        "simtrans_kafka"
      ],
      "destinations": {
        "kafka_archive": "ab-retorno-renavam-eventos (raw data)",
        "rabbitmq_sentry": "RabbitMQ SENTRY (empresa MULTIWAY)",
        "http_protenet": "HTTP PROTENET (empresa PROTENET)",
        "kafka_simtrans": "Kafka SIMTRANS-VCA-BA (empresa SIMTRANS_VCA)"
      }
    },
    "empresas_suportadas": [
      "SENTRY (MULTIWAY)",
      "PROTENET"
    ],
    "protocolos": [
      "Kafka",
      "AMQP 0.9",
      "HTTP"
    ],
    "status": "HEALTHY"
  }
}
```

#### Mensagem Legível (stdout)
```
========================================
[HEALTH CHECK] Pipeline AB Retorno RENAVAM
Status: OPERACIONAL ✓
Outputs Ativos: 4/4
Empresas: 2 (SENTRY, PROTENET)
Protocolos: 3 (Kafka, AMQP, HTTP)
========================================
```

## 🔍 Interpretação dos Health Checks

### Status HEALTHY

Quando o campo `status` está como `"HEALTHY"`, significa:

- ✅ Pipeline está processando mensagens
- ✅ Todos os 4 outputs estão configurados e alcançáveis
- ✅ Sem erros críticos detectados no momento do health check
- ✅ Roteamento funcionando (empresas SENTRY e PROTENET)

### Campos Importantes

| Campo | Descrição | Valores Esperados |
|-------|-----------|-------------------|
| `timestamp` | Data/hora do health check (fuso SP) | String datetime |
| `timestamp_unix` | Unix timestamp | Número inteiro |
| `outputs.total` | Total de outputs configurados | `4` |
| `outputs.active` | Lista de outputs | Array com 4 elementos |
| `empresas_suportadas` | Empresas roteadas | `["SENTRY (MULTIWAY)", "PROTENET"]` |
| `protocolos` | Protocolos em uso | `["Kafka", "AMQP 0.9", "HTTP"]` |
| `status` | Estado geral | `"HEALTHY"` |

## ⚠️ Sinais de Alerta

### Ausência de Logs (> 20 minutos)

**Sintoma:** Último health check foi há mais de 20 minutos

**Possíveis Causas:**
- Pipeline parado/crashado
- Serviço Bento inativo
- Sem fluxo de mensagens do input (Kafka)

**Ações:**
```bash
# 1. Verificar status do serviço
systemctl status bento-streams

# 2. Verificar últimos logs gerais
journalctl -u bento-streams -n 100

# 3. Verificar se há mensagens no Kafka input
# (comando específico depende da ferramenta de monitoramento Kafka)
```

### Outputs Faltando na Lista

**Sintoma:** Campo `outputs.active` tem menos de 4 elementos

**Possíveis Causas:**
- Configuração de output incorreta
- Variáveis de ambiente faltando
- Erro de sintaxe YAML

**Ações:**
```bash
# 1. Validar sintaxe do pipeline
bento lint streams/ab_retorno_renavam.yaml

# 2. Verificar variáveis de ambiente
grep -E "RABBITMQ|HTTP_OUTPUT|DEV_KAFKA" config/.env

# 3. Verificar logs de erro específicos
journalctl -u bento-streams | grep -i "error.*output"
```

### Status Diferente de HEALTHY

**Sintoma:** Campo `status != "HEALTHY"`

**Nota:** Na implementação atual, o status é sempre `"HEALTHY"` se o log aparecer. Versões futuras podem incluir lógica de detecção de degradação.

## 📊 Métricas Complementares (Prometheus/Grafana)

### Health Checks vs. Métricas

Os health checks **complementam** (não substituem) as métricas:

| Aspecto | Health Checks | Métricas Prometheus |
|---------|---------------|---------------------|
| **Tipo** | Qualitativo (status, configuração) | Quantitativo (throughput, latência, erros) |
| **Frequência** | ~15 minutos | Contínuo (scrape interval) |
| **Formato** | Logs estruturados | Time series |
| **Uso** | Troubleshooting rápido | Análise detalhada, alertas |
| **Visibilidade** | Logs do serviço | Dashboard Grafana |

### Principais Métricas Configuradas

#### Métricas Gerais
```promql
# Total de mensagens recebidas
renavam_messages_received_total

# Total de mensagens enviadas por destino
renavam_messages_sent_total{destination="sentry"}
renavam_messages_sent_total{destination="navegantes"}
renavam_messages_sent_total{destination="simtrans"}

# Mensagens por status RENAVAM
renavam_messages_by_status{status="OK"}
renavam_messages_by_status{status="NAO_ENCONTRADO"}
```

#### Métricas RabbitMQ SENTRY
```promql
# Contador de mensagens enviadas para RabbitMQ SENTRY
renavam_rabbitmq_sentry_sent_total

# Taxa de erros RabbitMQ
output_error_total{label="ab_retorno_renavam_output_sentry"}

# Latência RabbitMQ (histograma)
output_latency_ns_bucket{label="ab_retorno_renavam_output_sentry"}
```

#### Métricas HTTP PROTENET
```promql
# Contador de mensagens enviadas para HTTP PROTENET
renavam_http_navegantes_sent_total

# Taxa de erros HTTP
output_error_total{label="ab_retorno_renavam_output_navegantes"}
```

### Dashboard Grafana

**Dashboard:** RENAVAM - AB Retorno  
**UID:** `renavam_dashboard`  
**Localização:** `docker/grafana/provisioning/dashboards/02_renavam.json`

**Seções:**
1. **Input** - Mensagens recebidas, throughput
2. **Processing** - Status RENAVAM, órgãos, empresas
3. **RabbitMQ Output (SENTRY)** - Envios, erros, latência (6 painéis)
4. **HTTP Output (PROTENET)** - Envios, erros, latência
5. **Output Consolidado** - Visão geral de todos outputs
6. **System** - Recursos do sistema

## 🛠️ Comandos de Monitoramento

### Ver Últimos Health Checks

```bash
# Últimos 5 health checks
journalctl -u bento-streams | grep "HEALTH CHECK" | tail -5

# Health checks da última hora
journalctl -u bento-streams --since "1 hour ago" | grep "HEALTH CHECK"

# Health check mais recente (apenas timestamp)
journalctl -u bento-streams | grep "HEALTH CHECK" | tail -1 | \
  jq -r '.health_check.timestamp'
```

### Monitorar em Tempo Real

```bash
# Seguir logs incluindo health checks e erros
journalctl -u bento-streams -f | grep --line-buffered -E "HEALTH CHECK|ERROR|WARN"

# Apenas health checks
journalctl -u bento-streams -f | grep --line-buffered "HEALTH CHECK"
```

### Extrair JSON do Health Check

```bash
# Extrair último health check como JSON
journalctl -u bento-streams -o json --since "1 hour ago" | \
  jq -r 'select(.health_check != null) | .health_check' | \
  tail -1

# Verificar outputs ativos
journalctl -u bento-streams -o json --since "1 hour ago" | \
  jq -r 'select(.health_check != null) | .health_check.outputs.active[]' | \
  sort -u
```

### Verificar Timestamp do Último Health Check

```bash
# Calcular há quanto tempo foi o último health check
LAST_HC=$(journalctl -u bento-streams -o json | \
  jq -r 'select(.health_check != null) | .health_check.timestamp_unix' | \
  tail -1)

NOW=$(date +%s)
DIFF=$((NOW - LAST_HC))

echo "Último health check: $((DIFF / 60)) minutos atrás"

# Alertar se > 20 minutos
if [ $DIFF -gt 1200 ]; then
  echo "⚠️  ALERTA: Health check atrasado!"
fi
```

## 🐛 Troubleshooting Baseado em Logs

### Cenário 1: Pipeline Processando Normalmente

**Indicadores:**
- Health check aparece a cada ~15 minutos
- Status: `HEALTHY`
- 4 outputs ativos
- Sem mensagens de ERROR nos logs

**Exemplo de Log:**
```
Mar 13 09:15:00 svn0145 bento[123]: {"health_check": {...}, "status": "HEALTHY"}
Mar 13 09:30:00 svn0145 bento[123]: {"health_check": {...}, "status": "HEALTHY"}
```

**Ação:** Nenhuma, pipeline operacional ✅

### Cenário 2: Sem Health Checks Recentes

**Indicadores:**
- Último health check > 20 minutos atrás
- Sem logs novos do serviço

**Comandos de Diagnóstico:**
```bash
# 1. Verificar se serviço está rodando
systemctl is-active bento-streams

# 2. Ver últimos logs (incluindo errors)
journalctl -u bento-streams -n 100

# 3. Verificar restart recente
systemctl status bento-streams | grep "Active:"

# 4. Se serviço parado, ver motivo
journalctl -u bento-streams --since "1 hour ago" | grep -i "exit\|crash\|fatal"
```

**Possíveis Soluções:**
- Reiniciar serviço: `systemctl restart bento-streams`
- Verificar configuração: `bento lint streams/ab_retorno_renavam.yaml`
- Verificar conectividade Kafka input

### Cenário 3: Erros em Output Específico

**Indicadores:**
- Health checks aparecendo normalmente
- Métricas Grafana mostram erros em output específico
- Logs contêm mensagens de erro

**Comandos de Diagnóstico:**
```bash
# Filtrar erros RabbitMQ SENTRY
journalctl -u bento-streams --since "1 hour ago" | \
  grep -i "rabbitmq\|sentry\|amqp" | grep -i "error\|fail"

# Filtrar erros HTTP PROTENET
journalctl -u bento-streams --since "1 hour ago" | \
  grep -i "http\|protenet\|navegantes" | grep -i "error\|fail"

# Erros gerais de output
journalctl -u bento-streams --since "1 hour ago" | \
  grep -i "output.*error"
```

**Possíveis Soluções:**
- **RabbitMQ:** Verificar credenciais, conectividade, permissões
- **HTTP:** Verificar token, URL, timeout
- **Kafka:** Verificar broker, tópico, autenticação

### Cenário 4: Latência Alta

**Indicadores:**
- Health checks normais
- Grafana mostra latência p99 > 5s em algum output
- Pipeline "travando" periodicamente

**Comandos de Diagnóstico:**
```bash
# Verificar tamanho das filas de output (se disponível nas métricas)
curl -s http://localhost:4195/metrics | grep "output.*lag\|output.*queue"

# Verificar se há backpressure
journalctl -u bento-streams --since "30 minutes ago" | \
  grep -i "backpressure\|slow\|timeout"
```

**Possíveis Soluções:**
- Aumentar `max_in_flight` nos outputs
- Ajustar `batching` (count/period)
- Verificar capacidade do destino (RabbitMQ, HTTP endpoint)

## 📈 Evolução Futura

### Melhorias Planejadas

1. **Health Check Endpoint HTTP**
   - Expor `/health` endpoint para probes externos (Kubernetes, load balancers)
   - Retornar status baseado em checagens ativas

2. **Detecção de Degradação**
   - Lógica para marcar status como `DEGRADED` se:
     - Taxa de erro > 1%
     - Latência p99 > threshold
     - Algum output inacessível

3. **Estatísticas no Health Check**
   - Incluir contadores de mensagens processadas
   - Média de throughput (msgs/s)
   - Uptime do pipeline

4. **Integração com Alertas Proativos**
   - Webhooks para Slack/Teams/PagerDuty
   - Alertas baseados em ausência de health checks
   - Correlação com métricas Prometheus

5. **Tracing Distribuído**
   - OpenTelemetry integration
   - Trace IDs para rastreamento end-to-end
   - Correlação entre logs, métricas e traces

### Issues Relacionadas

- **Issue #46** - Implementação de health check logs periódicos ✅
- **Issue #XX** (futura) - Alertas Grafana proativos
- **Issue #XX** (futura) - Health check endpoint HTTP
- **Issue #XX** (futura) - OpenTelemetry tracing

## 🔗 Referências

### Documentação Interna
- [README Principal](README.md) - Visão geral do projeto
- [Release v1.3.0](releases/v1.3.0-observability.md) - Detalhes da implementação
- [SENTRY RabbitMQ Implementation](SENTRY_RABBITMQ_IMPLEMENTATION.md) - Guia SENTRY

### Documentação Externa
- [Bento Documentation](https://warpstreamlabs.github.io/bento/docs/about) - Referência oficial
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)

## 💡 Dicas Operacionais

### 1. Ajustar Frequência do Health Check

Se precisar alterar a frequência (atualmente ~15 minutos = 900 segundos):

**Arquivo:** `streams/ab_retorno_renavam.yaml`  
**Linha:** ~149

```yaml
# Alterar o valor 900 para outro intervalo desejado (em segundos)
# Nota: Amostragem adicional (random_int) reduz logs duplicados no mesmo segundo
root = if now().ts_unix() % 900 == 0 && random_int(min: 0, max: 7) == 0 { 
  this 
} else { 
  deleted() 
}

# Exemplos de intervalos alternativos:
# - A cada 5 minutos: % 300
# - A cada 10 minutos: % 600
# - A cada 30 minutos: % 1800

# Para ajustar probabilidade de amostragem (evitar logs múltiplos):
# - random_int(min: 0, max: 3) == 0  → 1/4 (25% chance)
# - random_int(min: 0, max: 7) == 0  → 1/8 (12.5% chance) [atual]
# - random_int(min: 0, max: 15) == 0 → 1/16 (6.25% chance)
```

**Após alteração:**
```bash
# Validar sintaxe
bento lint streams/ab_retorno_renavam.yaml

# Reiniciar serviço
systemctl restart bento-streams
```

### 2. Desabilitar Health Checks

Se por algum motivo precisar desabilitar temporariamente:

**Arquivo:** `streams/ab_retorno_renavam.yaml`  
**Linha:** ~147

```yaml
# Comentar todo o bloco branch do health check
# - branch:
#     request_map: |
#       root = if now().ts_unix() % 900 == 0 { this } else { deleted() }
#     ...
```

### 3. Adicionar Campos Customizados

Para incluir informações adicionais no health check:

**Arquivo:** `streams/ab_retorno_renavam.yaml`  
**Linha:** ~156-179

```yaml
fields_mapping: |
  root.health_check = {
    # ... campos existentes ...
    "custom_field": "custom_value",
    "environment": "${ENVIRONMENT_NAME:production}"
  }
```

## 📞 Suporte

Para questões sobre observabilidade do pipeline:

- **Desenvolvedor:** Magno Pereira
- **Repositório GitLab:** git.prf.gov.br/magno.pereira/ds-bento-streams
- **Issues GitHub:** github.com/alerta-brasil/deltaserve (issues/milestones)
- **Milestone:** [Fase 1] Pipeline AB Retorno RENAVAM

---

**Última Atualização:** 13 Mar 2026  
**Versão:** v1.3.0  
**Status:** Ativo em Produção
