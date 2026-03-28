# OpenCode Agents - Campeiro

Este diretório contém a configuração de agentes OpenCode para o projeto **Campeiro**.

## Estrutura

```
.opencode/
├── README.md              # Este arquivo
├── agents/                # Agentes especializados
│   ├── repo-manager.md   # Gestão Git (commits, branches, push)
│   └── github-manager.md # Gestão GitHub/GitLab (issues, milestones)
└── config/                # Configurações opcionais
```

## Agentes Disponíveis

### 1. repo-manager

**Modo**: `subagent`  
**Responsabilidade**: Gestão Git com Conventional Commits em português

**Quando usar:**
- Criar commits após implementação de pipelines
- Sugerir mensagens de commit padronizadas
- Gerenciar branches (feature, bugfix)
- Push para remote (sempre com confirmação)

**Exemplo de uso:**
```
@repo-manager crie um commit:
- Tipo: feat
- Escopo: pipeline
- Descrição: adiciona pipeline ab_retorno_renavam
- Corpo: <detalhamento técnico>
- Issue: Refs: #46
```

### 2. github-manager

**Modo**: `subagent`  
**Responsabilidade**: Gestão de issues e milestones no GitHub/GitLab

**Quando usar:**
- Criar issues para novos pipelines
- Listar issues por milestone/label
- Fechar issues após deploy
- Sugerir comandos `gh` com templates

**Exemplo de uso:**
```
@github-manager crie uma issue para:
- Pipeline: ab_retorno_renavam
- Input: Kafka topic ab.retorno.renavam
- Output: ClickHouse ds1.ab_retorno_renavam
- Milestone: [Fase 1] Pipeline AB Retorno RENAVAM
```

## Configuração

A configuração principal está em `opencode.json` na raiz do projeto.

Configurações globais são herdadas de `~/.config/opencode/opencode.json`.

## Skills Disponíveis

### bento-bloblang

Skill para troubleshooting e desenvolvimento de pipelines Bento + Bloblang.

**Quando usar:**
- Debugar pipelines Bento
- Escrever/otimizar mapeamentos Bloblang
- Resolver problemas de schema validation
- Otimizar throughput/latência

**Como usar:**
```
Carregue a skill bento-bloblang antes de trabalhar com pipelines.
```

## Conventional Commits - Padrão do Projeto

**Formato obrigatório (português):**

```
<tipo>(<escopo>): <descrição curta em português>

<corpo detalhado em português>

Refs: #X ou Closes: #X
```

**Tipos:**
- `feat`: Novo pipeline, feature
- `fix`: Correção de bug
- `perf`: Otimização de performance
- `refactor`: Refatoração
- `docs`: Documentação
- `test`: Testes
- `chore`: Manutenção

**Escopos:**
- `pipeline`: Configurações Bento (bento/*.yaml)
- `bloblang`: Mapeamentos (bloblang/*.blobl)
- `dashboard`: Dashboards Grafana
- `docker`: Docker Compose, Dockerfiles
- `docs`: Documentação

**Exemplos:**
```bash
feat(pipeline): adiciona pipeline ab_retorno_renavam

Cria ingestão Kafka → ClickHouse com:
- Input: topic ab.retorno.renavam
- Bloblang: transformação e validação
- Output: ds1.ab_retorno_renavam

Refs: #46
```

```bash
fix(pipeline): corrige perda de mensagens no rebalanceamento

Adiciona checkpoint manual após batch write.

Closes: #47
```

## Templates de Issues

Templates GitHub/GitLab em `.github/ISSUE_TEMPLATE/`:

1. **01-pipeline-bento.yml**: Novo pipeline Bento
2. **02-otimizacao-stream.yml**: Otimização de throughput/latência
3. **03-bug-processamento.yml**: Bugs em pipelines

Use via GitHub web UI ou comandos `gh` sugeridos pelo `@github-manager`.

## Mais Informações

- **Projeto**: Campeiro — plataforma de stream processing e roteamento de mensagens
- **Stack**: Bento + Bloblang + Kafka + ClickHouse
- **Repositório**: https://github.com/delta-serve/campeiro
- **Documentação**: ../docs/README.md
- **Versão**: 2.0.0

---

**Última atualização**: 2026-03-28  
**Autor**: Magno Pereira
