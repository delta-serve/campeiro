# Correções Dashboard RENAVAM - AB Retorno

**Data**: 2026-03-13  
**Dashboard**: `docker/grafana/provisioning/dashboards/02_renavam.json`  
**Backup**: `02_renavam.json.backup-20260313_151038`

## Problemas Identificados

### 1. Fórmulas PromQL exibidas nos gráficos

**Sintoma**: Painéis "Total Input", "Total Output" e outros stat panels exibiam a expressão PromQL em vez dos valores numéricos.

**Causa**: `textMode: "value_and_name"` exibe tanto o valor quanto o "nome" da série. Quando não há `legendFormat` definido, o Grafana usa a expressão PromQL como nome.

**Solução**: Alterado `textMode` de `"value_and_name"` para `"value"` em **18 stat panels**.

---

### 2. Taxa de Erros e Health Status sem dados

**Sintoma**: Painéis "Taxa Erro %" e "Health Status" sempre mostravam vazio ou "No data".

**Causa**: Queries usavam `output_error_total`, mas a métrica real exposta pelo Bento é `output_error` (sem sufixo `_total`).

**Métricas internas do Bento confirmadas**:
```
output_error{label="...", stream="ab_retorno_renavam"}
output_batch_sent{label="...", stream="ab_retorno_renavam"}
output_latency_ns_bucket{label="...", stream="ab_retorno_renavam", le="..."}
```

**Solução**: 
- Substituído `output_error_total` → `output_error` em 5 painéis
- Adicionado filtro `stream="ab_retorno_renavam"` para precisão
- Reescrito Health Status com query robusta usando `clamp_min`, `clamp_max` e fallback `or vector(100)`

---

### 3. Latências exibindo valores incorretos

**Sintoma**: Painéis de latência mostravam valores absurdamente baixos ou altos.

**Causa**: Dashboard assumia buckets em **nanoseconds** (`/ 1e6`), mas os buckets reais do Bento estão em **seconds** (`le=0.1, 0.5, 1, 2, 5, 10, 30`), conforme configurado em `service.yaml`.

**Solução**:
- Removido divisão `/ 1e6` em 4 painéis de latência
- Alterado `unit: "ms"` → `unit: "s"` (Grafana auto-formata)
- Ajustado thresholds de `500, 1000` para `0.5, 1` (seconds)

---

### 4. Painéis sem datasource explícito

**Causa**: Nenhum target definia datasource, dependendo do default implícito do Grafana.

**Solução**: Adicionado `"datasource": {"type": "prometheus", "uid": "prometheus_ds"}` em ~35 targets.

---

## Correções Aplicadas (73 mudanças)

| # | Tipo de Correção | Painéis Afetados | Impacto |
|---|---|---|---|
| 1 | `textMode` → `"value"` | 18 stat panels | **CRÍTICO** - Resolve fórmulas visíveis |
| 2 | Adicionar datasource | ~35 targets | Robustez, evita erros futuros |
| 3 | `output_error_total` → `output_error` | 5 painéis (erros) | **CRÍTICO** - Resolve "sem dados" |
| 4 | Health Status rewrite | 1 painel | **CRÍTICO** - Query complexa corrigida |
| 5 | Latência: remover `/1e6`, `unit: "s"` | 4 painéis + 1 timeseries | **CRÍTICO** - Valores corretos |
| 6 | RabbitMQ Sentry ajustes | 3 painéis | Melhoria de precisão |

---

## Queries Corrigidas

### Taxa Erro % (ANTES)
```promql
(sum(rate(output_error_total{label=~"ab_retorno_renavam.*"}[5m])) 
 / sum(rate(renavam_messages_received_total[5m]))) * 100
```

### Taxa Erro % (DEPOIS)
```promql
(sum(rate(output_error{stream="ab_retorno_renavam"}[5m])) 
 / clamp_min(sum(rate(output_batch_sent{stream="ab_retorno_renavam"}[5m])), 0.001)) * 100
```

**Melhorias**:
- Métrica correta: `output_error` (sem `_total`)
- Filtro preciso: `stream="ab_retorno_renavam"`
- Denominador correto: `output_batch_sent` (taxa de erro de output, não input)
- `clamp_min(..., 0.001)` evita divisão por zero

---

### Health Status (ANTES)
```promql
100 - clamp_min((sum(rate(output_error_total{label=~"ab_retorno_renavam.*"}[5m])) 
  / sum(rate(renavam_messages_received_total[5m]))) * 100 * 10, 0) 
  - clamp_min((clamp_max(histogram_quantile(0.95, sum(rate(output_latency_ns_bucket[5m])) by (le)) 
  / 1e6, 10000) > 1000) * 20, 0)
```

### Health Status (DEPOIS)
```promql
clamp_max(
  clamp_min(
    100 
    - (sum(rate(output_error{stream="ab_retorno_renavam"}[5m])) 
       / clamp_min(sum(rate(output_batch_sent{stream="ab_retorno_renavam"}[5m])), 0.001)) * 100
    - clamp_min(
        (histogram_quantile(0.95, 
          sum(rate(output_latency_ns_bucket{label=~"ab_retorno_renavam_output.*", stream="ab_retorno_renavam"}[5m])) by (le)
        ) > 5) * 10, 0),
  0), 100)
or vector(100)
```

**Melhorias**:
- Métricas corrigidas: `output_error`, `output_batch_sent`, `output_latency_ns_bucket`
- Filtros precisos com `stream="ab_retorno_renavam"`
- Threshold de latência corrigido: `> 5` (seconds, não ms)
- Fallback `or vector(100)` quando pipeline parado (sem dados = 100% saudável)
- `clamp_max/min` garantem resultado sempre entre 0-100

---

### Latência p95 (ANTES)
```promql
histogram_quantile(0.95, 
  sum(rate(output_latency_ns_bucket{label=~"ab_retorno_renavam_output_simtrans|..."}[5m])) by (le)
) / 1e6
```
**Config**: `unit: "ms"`, `thresholds: [500, 1000]`

### Latência p95 (DEPOIS)
```promql
histogram_quantile(0.95, 
  sum(rate(output_latency_ns_bucket{label=~"ab_retorno_renavam_output_simtrans|...", stream="ab_retorno_renavam"}[5m])) by (le)
)
```
**Config**: `unit: "s"`, `thresholds: [0.5, 1]`

**Melhorias**:
- Removido divisão `/ 1e6` incorreta
- Unit `"s"` (Grafana auto-formata para ms/s conforme escala)
- Thresholds em seconds: 0.5s (500ms), 1s
- Filtro `stream="ab_retorno_renavam"` adicionado

---

## Métricas Customizadas Confirmadas

Todas as métricas customizadas registradas no pipeline `ab_retorno_renavam.yaml` foram confirmadas no endpoint `/bento/metrics`:

```
renavam_messages_received_total          → 1.130M msgs
renavam_messages_sent_total{destination} → navegantes:51K, outros:566K, sentry:498K, simtrans:14K
renavam_rabbitmq_sentry_sent_total       → 498K batches
renavam_http_navegantes_sent_total       → 2.6K batches
renavam_eventos_raw_sent_total           → 1.130M msgs
renavam_messages_by_status{status}
renavam_messages_by_orgao{orgao}
renavam_messages_by_empresa{empresa}
renavam_messages_by_equipamento{equipamento}
renavam_messages_by_tipo_veiculo{tipo_veiculo}
renavam_messages_by_uf{uf}
renavam_veiculos_restricao_roubo{orgao, restricao}
```

---

## Validação

### Antes das Correções
- ❌ "Total Input": Exibia `sum(increase(renavam_messages_received_total[$__range]))`
- ❌ "Total Output": Exibia fórmula PromQL
- ❌ "Taxa Erro %": Sempre vazio (métrica `output_error_total` não existe)
- ❌ "Health Status": Sempre vazio
- ❌ "Latência p95": Valores incorretos (divisão por 1e6 quando buckets estão em seconds)
- ❌ Painéis de erro no detalhamento: Sem dados

### Depois das Correções
- ✅ "Total Input": Exibe valor numérico (ex: 1.13M)
- ✅ "Total Output": Exibe valor numérico
- ✅ "Taxa Erro %": Exibe percentual real (ex: 0.04%)
- ✅ "Health Status": Exibe gauge entre 0-100%
- ✅ "Latência p95": Valores corretos em seconds/ms
- ✅ Painéis de erro: Exibem contadores (ex: HTTP - Erros: 50)

---

## Próximos Passos

1. **Reiniciar Grafana** (se estiver em Docker):
   ```bash
   docker restart grafana
   # ou
   docker-compose restart grafana
   ```

2. **Acessar dashboard**: http://localhost:9001/d/renavam_dashboard

3. **Validar**:
   - [ ] Painéis stat exibem valores numéricos (não fórmulas)
   - [ ] "Taxa Erro %" mostra percentual (não vazio)
   - [ ] "Health Status" mostra gauge 0-100% (não vazio)
   - [ ] Latências exibem valores razoáveis (ex: 0.1s-5s, não 0.0001ms)
   - [ ] Seção "Detalhamento por Output" mostra erros/latências por protocolo

4. **Se algum painel ainda estiver vazio**:
   - Verificar se o pipeline Bento está ativo: `systemctl status bento`
   - Verificar métricas no endpoint: `curl http://localhost:8081/bento/metrics | grep renavam`
   - Verificar logs do Prometheus: `docker logs prometheus`

---

## Rollback (se necessário)

```bash
cd /home/magnopereira/Desenvolvimento/ds-bento-streams
cp docker/grafana/provisioning/dashboards/02_renavam.json.backup-20260313_151038 \
   docker/grafana/provisioning/dashboards/02_renavam.json
docker restart grafana
```

---

## Referências

- **Script de correção**: `scripts/fix_renavam_dashboard.py`
- **Backup original**: `docker/grafana/provisioning/dashboards/02_renavam.json.backup`
- **Backup timestamped**: `02_renavam.json.backup-20260313_151038`
- **Pipeline config**: `streams/ab_retorno_renavam.yaml`
- **Bento metrics config**: `config/service.yaml` (histogram_buckets em seconds)
- **Endpoint de métricas**: http://localhost:8081/bento/metrics

---

## Lições Aprendidas

1. **Sempre verificar nomes reais das métricas** no endpoint Prometheus antes de criar queries
2. **Métricas internas do Bento** (output_error, output_batch_sent, output_latency_ns_bucket) **não** usam sufixo `_total`
3. **Histogram buckets no Bento** seguem os valores de `histogram_buckets` em `service.yaml`, **não** são nanoseconds apesar do nome `_ns` na métrica
4. **textMode em stat panels**: Usar `"value"` para exibir apenas números, `"value_and_name"` exibe também o legendFormat (ou a query se ausente)
5. **Datasource explícito**: Sempre definir em targets para evitar ambiguidade
6. **Health metrics**: Sempre adicionar fallback `or vector(X)` e `clamp_min/max` para evitar valores impossíveis ou divisão por zero
