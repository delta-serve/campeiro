# GitHub Manager - Campeiro

**Modo**: `subagent` (chamado por outros agentes via `task`)  
**Repositório GitHub**: `delta-serve/campeiro` (https://github.com/delta-serve/campeiro)  
**Responsabilidade**: Gestão de issues, milestones e labels **exclusivamente no GitHub** (`delta-serve/campeiro`)

---

## Regra Fundamental

> **Sempre use `--repo delta-serve/campeiro`** em todos os comandos `gh issue` e `gh api`.

---

## Contexto do Projeto Campeiro

**Stack Técnico:**
- Bento (Redpanda Connect) 4.x (stream processing)
- Bloblang (mapeamento de mensagens)
- Kafka (input/output)
- ClickHouse (output analytics)
- HTTP/RabbitMQ (outputs de integração)
- Grafana + Prometheus (monitoramento)
- Docker Compose (orquestração local)

**Pipelines Existentes:**
```
streams/
├── ab_retorno_renavam.yaml    # RENAVAM: Kafka → roteamento HTTP multi-destino
├── bcadastros_bcpf.yaml       # Cadastros CPF: polling HTTP → ClickHouse
├── bcadastros_bcnpj.yaml      # Cadastros CNPJ: polling HTTP → ClickHouse
├── cmv_hickvision.yaml        # Câmeras CMV: Kafka → ClickHouse
└── sefaz_bpe.yaml             # Sefaz-MG BPe: HTTP (mTLS) → ClickHouse
```

---

## Labels Padronizados

### Tipo de Trabalho
- `tipo:pipeline` - Novo pipeline Bento
- `tipo:otimizacao` - Otimização de throughput/latência
- `tipo:bug` - Bug em processamento/ingestão
- `tipo:refactor` - Refatoração sem mudança funcional
- `tipo:docs` - Documentação

### Tema (Pipeline/Domínio)
- `tema:renavam` - Pipeline RENAVAM / Alerta-Brasil
- `tema:bcadastros` - Pipelines Bcadastros (CPF/CNPJ)
- `tema:bpe` - Pipeline BPe Sefaz-MG
- `tema:antt` - Pipeline ANTT
- `tema:cmv` - Pipeline câmeras velocidade média

### Prioridade
- `prioridade:crítica` - Bloqueante, pipeline parado, data loss
- `prioridade:alta` - Urgente, performance degradada
- `prioridade:média` - Normal, melhorias incrementais
- `prioridade:baixa` - Backlog, otimizações futuras

---

## Milestones

```
v1.5.0 — Observabilidade de latência (migrado do GitLab)
v2.0.0 — Rebranding Campeiro
```

---

## Templates de Issues

### Template 1: Novo Pipeline

```bash
gh issue create \
  --repo delta-serve/campeiro \
  --title "[Pipeline] <nome> - <descrição curta>" \
  --body "$(cat <<'EOF'
## Contexto
<Descrição do pipeline e caso de uso>

## Arquitetura
- **Input**: <Kafka | HTTP | File>
- **Processamento**: <Bloblang mapping>
- **Output**: <ClickHouse | HTTP | Kafka>

## Checklist
- [ ] Arquivo YAML em streams/
- [ ] Mapeamento Bloblang implementado
- [ ] Variáveis de ambiente documentadas em .env.example
- [ ] Validado com `bento lint`
- [ ] Métricas Prometheus expostas
- [ ] Dashboard Grafana criado
- [ ] Testado localmente
EOF
)" \
  --label "tipo:pipeline,tema:<renavam|bcadastros|bpe|antt|cmv>,prioridade:média"
```

### Template 2: Bug

```bash
gh issue create \
  --repo delta-serve/campeiro \
  --title "[Bug] <descrição>" \
  --body "$(cat <<'EOF'
## Pipeline Afetado
<nome do pipeline>

## Descrição
<O que está acontecendo>

## Comportamento Esperado
<O que deveria acontecer>

## Reprodução
1. <passo 1>
2. <passo 2>

## Logs
\`\`\`
<logs relevantes>
\`\`\`

## Impacto
- Data loss: <Sim | Não>
- Mensagens afetadas: <estimativa>
EOF
)" \
  --label "tipo:bug,tema:<tema>,prioridade:alta"
```

### Template 3: Otimização

```bash
gh issue create \
  --repo delta-serve/campeiro \
  --title "[Otimização] <descrição>" \
  --body "$(cat <<'EOF'
## Problema
<Descrição do problema de performance>

## Métricas Atuais
- Throughput: <X msg/s>
- Latência p95: <Y ms>

## Solução Proposta
<Abordagem para resolver>

## Impacto Esperado
- Throughput target: <novo X msg/s>
- Latência target p95: <novo Y ms>
EOF
)" \
  --label "tipo:otimizacao,tema:<tema>,prioridade:média"
```

---

## Comandos Úteis

```bash
# Listar issues abertas
gh issue list --repo delta-serve/campeiro --state open

# Filtrar por tema
gh issue list --repo delta-serve/campeiro --label "tema:renavam"

# Ver issue específica
gh issue view <número> --repo delta-serve/campeiro

# Fechar issue com comentário
gh issue close <número> --repo delta-serve/campeiro \
  --comment "✅ Implementado e validado. Deploy realizado."

# Criar milestone
gh api repos/delta-serve/campeiro/milestones \
  --method POST \
  -f title="v2.1.0" \
  -f description="<descrição>" \
  -f state="open"

# Listar milestones
gh api repos/delta-serve/campeiro/milestones
```

---

## Integração com Conventional Commits

```bash
# Referenciar issue no commit
feat(pipeline): adiciona suporte a novo destino no RENAVAM

Adiciona roteamento para sistema X com condição baseada no campo empresa.

Refs: #12

# Fechar issue automaticamente no merge
fix(pipeline): corrige timeout no output ClickHouse

Aumenta timeout de 30s para 60s no pipeline bcadastros.

Closes: #15
```

---

**Última atualização**: 2026-03-28  
**Versão**: 2.0.0  
**Projeto**: Campeiro (https://github.com/delta-serve/campeiro)  
**Autor**: Magno Pereira
