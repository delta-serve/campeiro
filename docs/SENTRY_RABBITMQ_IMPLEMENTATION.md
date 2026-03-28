# Implementação: Integração RabbitMQ SENTRY

## 📋 Informações da Configuração

### Conexão RabbitMQ SENTRY
- **Host:** `app.sentry.com.br`
- **Porta:** `5671` (AMQPS - com TLS)
- **Usuário:** `alertabrasil`
- **Senha:** `[configurar no .env]`
- **VHost:** `/` (padrão)
- **Exchange:** `alertabrasil.retornos`
- **Exchange Type:** `topic` (assumido - confirmar com SENTRY)
- **Routing Key:** `renavam.retorno` (sugestão - confirmar com SENTRY)
- **TLS:** Habilitado (porta 5671)

### URL de Conexão (formato AMQP)
```
amqps://alertabrasil:SENHA@app.sentry.com.br:5671/
```

---

## ⚙️ Variáveis de Ambiente Configuradas

As seguintes variáveis foram adicionadas ao arquivo `config/.env`:

```bash
## RabbitMQ - SENTRY (gerencia Mauá-SP e Osasco-SP)
RABBITMQ_SENTRY_HOST=app.sentry.com.br
RABBITMQ_SENTRY_PORT=5671
RABBITMQ_SENTRY_USER=alertabrasil
RABBITMQ_SENTRY_PASSWORD=ADICIONAR_SENHA_AQUI  # ⚠️ SUBSTITUIR PELA SENHA REAL
RABBITMQ_SENTRY_EXCHANGE=alertabrasil.retornos
RABBITMQ_SENTRY_EXCHANGE_TYPE=topic
RABBITMQ_SENTRY_ROUTING_KEY=renavam.retorno
RABBITMQ_SENTRY_VHOST=/
RABBITMQ_SENTRY_TLS_ENABLED=true
RABBITMQ_SENTRY_URL=amqps://${RABBITMQ_SENTRY_USER}:${RABBITMQ_SENTRY_PASSWORD}@${RABBITMQ_SENTRY_HOST}:${RABBITMQ_SENTRY_PORT}${RABBITMQ_SENTRY_VHOST}
```

### ⚠️ AÇÃO NECESSÁRIA
**Substituir `ADICIONAR_SENHA_AQUI` pela senha real fornecida pela SENTRY!**

---

## 🔧 Próximos Passos para Implementação

### 1. Confirmar Detalhes Técnicos com SENTRY
Antes de implementar, confirmar com a SENTRY:

- [ ] **Exchange Type:** É realmente `topic`? (ou `direct`/`fanout`?)
- [ ] **Routing Key:** Qual routing key usar? (sugestão: `renavam.retorno`)
- [ ] **Certificados TLS:** Necessário certificado CA específico?
- [ ] **Message Format:** JSON? Algum schema específico?
- [ ] **Message Persistence:** Mensagens devem ser persistentes (durable)?
- [ ] **Publisher Confirms:** Habilitar confirmação de publicação?
- [ ] **Queue específica:** A SENTRY já tem uma queue criada ou será auto-criada?

### 2. Atualizar Pipeline Bento
Modificar o arquivo `streams/ab_retorno_renavam.yaml`:

#### a) Adicionar Output RabbitMQ
```yaml
output:
  broker:
    pattern: fan_out
    outputs:
      # ... outputs existentes ...
      
      - label: rabbitmq_sentry
        amqp_0_9:  # RabbitMQ usa AMQP 0.9.1
          urls:
            - "${RABBITMQ_SENTRY_URL}"
          exchange: "${RABBITMQ_SENTRY_EXCHANGE}"
          exchange_type: "${RABBITMQ_SENTRY_EXCHANGE_TYPE}"
          exchange_declare:
            enabled: false  # assumindo que exchange já existe
            durable: true
          key: "${RABBITMQ_SENTRY_ROUTING_KEY}"
          type: ""
          content_type: "application/json"
          content_encoding: "utf-8"
          metadata:
            exclude_prefixes: []
          priority: 0
          mandatory: false
          immediate: false
          persistent: true  # mensagens persistentes
          tls:
            enabled: true
            skip_cert_verify: false  # validar certificado
          max_in_flight: 64
          timeout: "30s"
```

#### b) Atualizar Roteamento Bloblang
```yaml
pipeline:
  processors:
    - branch:
        request_map: |
          root = this
          meta destination = match {
            this.empresa == "PROTENET" && this.equipamento.starts_with("RADAR") => "http_navegantes_sc",
            this.empresa == "SENTRY" => "rabbitmq_sentry",  # NOVA REGRA
            this.empresa == "SIMTRANS_VCA" => "kafka_simtrans_vca_ba",
            _ => "dlq_unrouted"
          }
```

#### c) Adicionar Métricas RabbitMQ
```yaml
metrics:
  prometheus:
    # Métricas existentes...
    
    # Novas métricas RabbitMQ
    - name: rabbitmq_messages_sent_total
      type: counter
      labels:
        destination: sentry
    - name: rabbitmq_messages_error_total
      type: counter
      labels:
        destination: sentry
        error_type: ""
    - name: rabbitmq_publish_latency_seconds
      type: histogram
      labels:
        destination: sentry
    - name: rabbitmq_connection_active
      type: gauge
      labels:
        destination: sentry
```

### 3. Configurar Retry e Error Handling
```yaml
      - label: rabbitmq_sentry
        processors:
          - retry:
              max_retries: 3
              backoff:
                initial_interval: 1s
                max_interval: 60s
          - catch:
              - log:
                  level: ERROR
                  message: "Falha ao enviar para SENTRY RabbitMQ: ${! error() }"
              - metric:
                  type: counter
                  name: rabbitmq_sentry_errors_total
                  labels:
                    error: "${! error() }"
```

### 4. Testar Conexão
Antes de ativar o pipeline completo, testar conexão:

```bash
# Teste de conexão RabbitMQ (usando rabbitmqadmin ou curl)
curl -i -u alertabrasil:SENHA https://app.sentry.com.br:15671/api/overview

# Ou usar ferramenta de linha de comando
rabbitmqadmin -H app.sentry.com.br -P 15671 -u alertabrasil -p SENHA list exchanges
```

### 5. Validação em Homologação
- [ ] Configurar pipeline em ambiente de homologação
- [ ] Enviar eventos de teste
- [ ] Validar recebimento pela SENTRY
- [ ] Verificar métricas no Grafana
- [ ] Testar cenários de erro (RabbitMQ offline)
- [ ] Validar retry logic

### 6. Documentação
- [ ] Atualizar README.md com informações da integração SENTRY
- [ ] Documentar troubleshooting específico do RabbitMQ
- [ ] Criar runbook para operação

---

## 📊 Impacto Esperado

### Performance
- **Throughput:** ~1.500 eventos/min (MAUA + OSASCO combinados)
- **Latência P95:** < 200ms (incluindo TLS handshake)
- **Taxa de sucesso:** 99.9% (com retry)

### Arquitetura
**Antes:**
```
Input (Kafka) → Routing → [kafka_maua_sp, kafka_osasco_sp, http_navegantes_sc, kafka_simtrans_vca_ba]
```

**Depois:**
```
Input (Kafka) → Routing → [rabbitmq_sentry, http_navegantes_sc, kafka_simtrans_vca_ba]
                           ↑
                           └─ Atende MAUA + OSASCO
```

### Redução de Outputs
- **Antes:** 4 outputs (2 Kafka para SENTRY + 1 HTTP + 1 Kafka)
- **Depois:** 3 outputs (1 RabbitMQ para SENTRY + 1 HTTP + 1 Kafka)
- **Benefício:** Consolidação e simplificação

---

## 🔐 Segurança

### Checklist de Segurança
- [x] Senha armazenada em variável de ambiente (não em código)
- [x] TLS habilitado (porta 5671)
- [ ] Certificado TLS validado (skip_cert_verify: false)
- [ ] Revisar permissões do usuário RabbitMQ (apenas publicação no exchange)
- [ ] Rotação de credenciais configurada (agendar troca de senha)

---

## 🐛 Troubleshooting

### Erro: Connection Refused
```
Verificar:
1. Firewall permite conexão na porta 5671
2. Host está correto (app.sentry.com.br)
3. Credenciais estão corretas
```

### Erro: TLS/SSL Handshake Failed
```
Verificar:
1. Certificado CA está correto
2. Certificado não expirou
3. skip_cert_verify está false
```

### Erro: Exchange Not Found
```
Verificar:
1. Nome do exchange está correto (alertabrasil.retornos)
2. Exchange foi criado no RabbitMQ
3. Usuário tem permissão para publicar no exchange
```

### Mensagens não chegam na SENTRY
```
Verificar:
1. Routing key está correto
2. Queue está bound ao exchange com binding key correto
3. Consumer da SENTRY está ativo
```

---

## 📞 Contatos

**Responsável técnico SENTRY:** [adicionar contato]
**Suporte RabbitMQ:** [adicionar contato]

---

## ✅ Checklist de Ativação

### Pré-Produção
- [ ] Senha configurada no .env
- [ ] Detalhes técnicos confirmados com SENTRY
- [ ] Pipeline atualizado com output RabbitMQ
- [ ] Roteamento Bloblang atualizado
- [ ] Métricas configuradas
- [ ] Teste de conexão realizado
- [ ] Validação em homologação concluída

### Produção
- [ ] Deploy em produção agendado
- [ ] Monitoramento configurado
- [ ] Alertas configurados (Grafana/Prometheus)
- [ ] Runbook de operação documentado
- [ ] Equipe SENTRY notificada
- [ ] Rollback plan definido

---

## 📝 Notas Adicionais

### Sobre Exchange Type "topic"
Se o exchange for do tipo `topic`, a routing key suporta wildcards:
- `*` (asterisco) = exatamente uma palavra
- `#` (hash) = zero ou mais palavras

Exemplos de binding keys que podem ser usadas pela SENTRY:
- `renavam.retorno` - match exato
- `renavam.*` - qualquer evento renavam
- `#.retorno` - qualquer retorno
- `#` - todos os eventos

**Recomendação:** Confirmar com SENTRY qual binding key eles configuraram na queue.

### Sobre Persistência de Mensagens
Com `persistent: true`, mensagens sobrevivem a restart do RabbitMQ, mas impactam performance (~2-5x mais lento). Avaliar necessidade com SENTRY.

### Sobre Publisher Confirms
Para garantir que RabbitMQ recebeu a mensagem, podemos habilitar publisher confirms:
```yaml
amqp_0_9:
  # ... config ...
  wait_for_ack: true  # aguarda confirmação do RabbitMQ
```

Isso adiciona latência mas garante entrega.
