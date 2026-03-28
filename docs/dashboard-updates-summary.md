# Resumo das Alterações - Dashboard Grafana e Pipeline Bento

## Data: 12/03/2026

---

## 🎯 Objetivo

Integrar o novo output RabbitMQ (SENTRY) no dashboard Grafana e corrigir configurações do pipeline Bento para conformidade com a especificação AMQP 0.9.

---

## ✅ Alterações Realizadas

### 1. Dashboard Grafana (`docker/grafana/provisioning/dashboards/02_renavam.json`)

#### 1.1. Nova Seção: "RabbitMQ Output (SENTRY)"

Adicionada nova seção com **6 painéis** entre as seções "HTTP Output" e "Output Consolidado":

1. **Total Enviados via RabbitMQ** (stat)
   - Métrica: `renavam_rabbitmq_sentry_sent_total`
   - Posição: (0, 110), 6x4

2. **Taxa RabbitMQ (batch/s)** (stat)
   - Métrica: `rate(renavam_rabbitmq_sentry_sent_total[1m])`
   - Posição: (6, 110), 6x4

3. **Erros RabbitMQ** (stat)
   - Métrica: `output_error_total{label="ab_retorno_renavam_output_sentry"}`
   - Thresholds: verde (0), vermelho (≥1)
   - Posição: (12, 110), 6x4

4. **Latência RabbitMQ (p99)** (stat)
   - Métrica: `histogram_quantile(0.99, output_latency_ns_bucket{label="ab_retorno_renavam_output_sentry"})`
   - Thresholds: verde (<1s), amarelo (≥1s), vermelho (≥5s)
   - Posição: (18, 110), 6x4

5. **RabbitMQ - Envios vs Erros** (timeseries)
   - 2 séries: Enviados (batch/s) e Erros/s
   - Posição: (0, 114), 12x8

6. **RabbitMQ - Latência p50 / p95 / p99** (timeseries)
   - 3 séries: p50, p95, p99
   - Posição: (12, 114), 12x8

#### 1.2. Atualização da Seção "Output Consolidado"

**Título atualizado:**
- De: `"Output Consolidado (Kafka + HTTP)"`
- Para: `"Output Consolidado (Kafka + HTTP + RabbitMQ)"`

**Painéis atualizados:**

1. **Total Output Consolidado** (piechart)
   - Adicionada série RabbitMQ (cor: purple)
   - Query: `sum(increase(renavam_rabbitmq_sentry_sent_total[$__range]))`
   - Filtro Kafka atualizado para excluir `destination="sentry"`

2. **Taxa Consolidada (msg/s)** (timeseries)
   - Adicionada série RabbitMQ (cor: purple)
   - Query Total atualizada para incluir RabbitMQ
   - Filtro Kafka atualizado para excluir `destination="sentry"`

3. **Erros Consolidados** (timeseries)
   - Adicionada série "Erros RabbitMQ" (cor: purple)
   - Query: `output_error_total{label="ab_retorno_renavam_output_sentry"}`
   - Removidas referências a `output_maua` e `output_osasco`

#### 1.3. Limpeza de Referências Antigas

**Seção "Kafka Output":**
- Removidas referências aos outputs individuais de Mauá e Osasco
- Queries atualizadas para excluir `destination="sentry"`
- Painel "Erros Kafka Output" agora filtra apenas: `simtrans`, `outros`, `eventos`

**Filtros globais:**
- Todos os painéis Kafka agora excluem: `destination!="navegantes"` E `destination!="sentry"`
- Isso garante que RabbitMQ seja contabilizado separadamente

---

### 2. Pipeline Bento (`streams/ab_retorno_renavam.yaml`)

#### 2.1. Correções de Configuração RabbitMQ

**Problema identificado:**
- Campos `exchange_type` e `batching` não são válidos no nível do output `amqp_0_9`

**Solução aplicada:**
1. Movido `exchange_type` para `exchange_declare.type` (campo correto segundo docs)
2. Removido `batching` do output (não suportado em `amqp_0_9`)
3. Envolvido output em `broker` com padrão `fan_out` para permitir processors
4. Movida métrica para `processors` do output (estrutura correta)

**Configuração final (linhas 172-197):**

```yaml
- check: this.empresa == "MULTIWAY"
  output:
    label: ab_retorno_renavam_output_sentry
    broker:
      pattern: fan_out
      outputs:
        - amqp_0_9:
            urls:
              - "amqps://${RABBITMQ_SENTRY_USER}:${RABBITMQ_SENTRY_PASSWORD}@${RABBITMQ_SENTRY_HOST}:${RABBITMQ_SENTRY_PORT}${RABBITMQ_SENTRY_VHOST}"
            exchange: "${RABBITMQ_SENTRY_EXCHANGE}"
            exchange_declare:
              enabled: true
              type: "${RABBITMQ_SENTRY_EXCHANGE_TYPE}"  # Corrigido
              durable: true
            key: "${RABBITMQ_SENTRY_ROUTING_KEY}"
            content_type: "application/json"
            content_encoding: "utf-8"
            persistent: true
            tls:
              enabled: true
            max_in_flight: 64
            timeout: "${RABBITMQ_SENTRY_TIMEOUT:30s}"
          processors:  # Corrigido
            - metric:
                name: renavam_rabbitmq_sentry_sent_total
                type: counter
                value: "1"
```

#### 2.2. Validação

**Comando executado:**
```bash
set -a && source config/.env && set +a && bento lint streams/ab_retorno_renavam.yaml
```

**Resultado:** ✅ **PASSOU** (sem erros, apenas avisos de variáveis de ambiente)

---

## 📊 Impacto nas Métricas

### Métricas RabbitMQ Disponíveis

1. **Contador customizado:**
   - `renavam_rabbitmq_sentry_sent_total` - Total de mensagens enviadas

2. **Métricas nativas Bento (label: `ab_retorno_renavam_output_sentry`):**
   - `output_error_total` - Total de erros
   - `output_latency_ns_bucket` - Histograma de latência (para percentis)
   - `output_sent_bytes` - Bytes enviados
   - `output_sent_total` - Total de mensagens (métrica nativa)

### Dashboard - Estrutura Final

**Total de seções:** 6
1. Overview (métricas gerais)
2. Eventos Brutos
3. Equipamentos
4. Kafka Output
5. HTTP Output (Navegantes)
6. **RabbitMQ Output (SENTRY)** ← NOVA
7. Output Consolidado (Kafka + HTTP + RabbitMQ)

**Total de painéis:** 37 → **43 painéis** (+6)

---

## 🔍 Pontos de Atenção

### 1. Batching

**Observação:** O output `amqp_0_9` não suporta batching nativo.

**Alternativa (se necessário):**
- Adicionar processor `archive` antes do output para criar batches JSON array
- Exemplo:
  ```yaml
  processors:
    - archive:
        format: json_array
    - metric: ...
  ```

### 2. Confirmação com SENTRY

**Pendente validação:**
- [ ] Exchange type: `topic` está correto?
- [ ] Routing key: `renavam.retorno` está correto?
- [ ] Certificados TLS: necessários ou somente autenticação básica?
- [ ] Formato: JSON individual ou array?

### 3. Testes Necessários

**Próximos passos:**
- [ ] Executar pipeline em ambiente de dev
- [ ] Validar conectividade RabbitMQ (`telnet app.sentry.com.br 5671`)
- [ ] Confirmar recebimento de eventos pela SENTRY
- [ ] Monitorar métricas no Grafana
- [ ] Validar taxa de envio e latência

---

## 📝 Arquivos Modificados

1. **`docker/grafana/provisioning/dashboards/02_renavam.json`**
   - Linhas modificadas: ~150 linhas
   - Adicionados: 6 painéis RabbitMQ
   - Atualizados: 5 painéis consolidados
   - Removidos: Referências a maua/osasco

2. **`streams/ab_retorno_renavam.yaml`**
   - Linhas 172-197: Output RabbitMQ SENTRY
   - Estrutura corrigida: broker → amqp_0_9 → processors

3. **`config/.env`** (sem alterações nesta etapa)
   - Variáveis já configuradas anteriormente

---

## ✅ Validações Realizadas

- [x] JSON dashboard válido (`jq empty`)
- [x] Sintaxe YAML pipeline válida (`bento lint`)
- [x] Métricas Prometheus corretamente nomeadas
- [x] Filtros de destino atualizados (excluindo "sentry" do Kafka)
- [x] Cores consistentes (Kafka: azul, HTTP: laranja, RabbitMQ: roxo)
- [x] Thresholds configurados (erros, latência)

---

## 🎨 Cores do Dashboard

| Protocolo | Cor     | Hex/Nome  |
|-----------|---------|-----------|
| Kafka     | Azul    | `blue`    |
| HTTP      | Laranja | `orange`  |
| RabbitMQ  | Roxo    | `purple`  |
| Total     | Verde   | `green`   |
| Erros     | Vermelho| `red`     |

---

## 📚 Referências

- [Bento AMQP 0.9 Output](https://docs.redpanda.com/redpanda-connect/components/outputs/amqp_0_9/)
- [Bento Broker Output](https://docs.redpanda.com/redpanda-connect/components/outputs/broker/)
- [Grafana Stat Panel](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/stat/)
- [Grafana Timeseries Panel](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/time-series/)

---

**Documentado por:** Claude (AI Assistant)  
**Revisado por:** Magno Pereira  
**Data:** 12/03/2026
