set dotenv-load := true
export BENTO_ENV := "config/.env"
export BENTO_API_URL := env_var_or("BENTO_API_URL", "http://localhost:4195")

# Lista as tarefas disponíveis
default:
    @just --list

#-----------------------------------------------------------------------------
# DOCKER (Redpanda, Console, Grafana, etc.)
#-----------------------------------------------------------------------------

# Inicia os serviços Docker em background
docker-start:
    docker compose --env-file config/.env -f docker/docker-compose.yml up -d

# Reinicia os serviços Docker
docker-restart:
    docker compose --env-file config/.env -f docker/docker-compose.yml restart

# Para os serviços Docker
docker-stop:
    docker compose --env-file config/.env -f docker/docker-compose.yml down

# Visualiza logs dos containers Docker (siga com -f no terminal se necessário)
docker-logs service="":
    docker compose --env-file config/.env -f docker/docker-compose.yml logs -f {{service}}

#-----------------------------------------------------------------------------
# BENTO (Redpanda Connect) — Gerenciamento via systemd
#-----------------------------------------------------------------------------

# Valida os arquivos de configuração e streams
bento-lint:
    bento --env-file config/.env lint config/service.yaml
    bento --env-file config/.env lint streams/*.yaml

# Inicia o serviço do Bento
bento-start:
    sudo systemctl start bento

# Para o serviço do Bento
bento-stop:
    sudo systemctl stop bento

# Reinicia o serviço do Bento (valida antes de reiniciar)
bento-restart: bento-lint
    sudo systemctl restart bento

# Recarrega o serviço do Bento via SIGHUP (ExecReload do systemd)
bento-reload: bento-lint
    sudo systemctl reload bento || (echo "⚠ Recarga via systemd indisponível, usando restart..." && sudo systemctl restart bento)

# Verifica o status atual do serviço
bento-status:
    sudo systemctl status bento

# Verifica e acompanha os logs do Bento
bento-logs lines="50":
    sudo journalctl -u bento -n {{lines}} -f

# Verifica se o Bento está respondendo via HTTP API
bento-health:
    @curl -sf {{BENTO_API_URL}}/bento/ready || echo "❌ Bento não está respondendo"

# Lista as streams ativas via API HTTP
bento-streams:
    @curl -sf {{BENTO_API_URL}}/bento/streams | python3 -m json.tool 2>/dev/null || echo "❌ Não foi possível listar streams"

#-----------------------------------------------------------------------------
# BENTO — Reload individual de pipelines via API HTTP
#-----------------------------------------------------------------------------

# Recarrega um pipeline específico via API HTTP (usage: just reload-pipeline <nome>)
reload-pipeline pipeline:
    #!/usr/bin/env bash
    set -euo pipefail
    STREAM_FILE="streams/{{pipeline}}.yaml"
    STREAM_ID="{{pipeline}}"
    BENTO_URL="{{BENTO_API_URL}}"

    if [ ! -f "$STREAM_FILE" ]; then
        echo "❌ Arquivo não encontrado: $STREAM_FILE"
        echo "Pipelines disponíveis:"
        ls -1 streams/*.yaml | sed 's|streams/||;s|\.yaml||'
        exit 1
    fi

    echo "🔍 Validando pipeline: $STREAM_ID"
    bento --env-file config/.env lint "$STREAM_FILE"

    echo "🚀 Aplicando pipeline: $STREAM_ID"
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST "$BENTO_URL/bento/streams/$STREAM_ID" \
        -H 'Content-Type: text/yaml' \
        --data-binary @"$STREAM_FILE")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Pipeline '$STREAM_ID' aplicado com sucesso (HTTP $HTTP_CODE)"
    else
        echo "❌ Falha ao aplicar pipeline '$STREAM_ID' (HTTP $HTTP_CODE)"
        echo "   Tentando restart completo do serviço..."
        sudo systemctl restart bento
        echo "✅ Serviço reiniciado"
    fi

# Recarrega todos os pipelines via API HTTP
reload-all-pipelines:
    #!/usr/bin/env bash
    set -euo pipefail
    BENTO_URL="{{BENTO_API_URL}}"

    echo "🔍 Validando todos os pipelines..."
    just bento-lint

    echo "🚀 Aplicando todos os pipelines..."
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST "$BENTO_URL/bento/streams" \
        -H 'Content-Type: application/x-ndjson' \
        $(for f in streams/*.yaml; do
            echo "-d" "@$f"
        done))

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Todos os pipelines aplicados com sucesso"
    else
        echo "❌ Falha ao aplicar pipelines (HTTP $HTTP_CODE)"
        echo "   Reiniciando serviço..."
        sudo systemctl restart bento
        echo "✅ Serviço reiniciado"
    fi

# Remove um pipeline via API HTTP (usage: just remove-pipeline <nome>)
remove-pipeline pipeline:
    #!/usr/bin/env bash
    set -euo pipefail
    STREAM_ID="{{pipeline}}"
    BENTO_URL="{{BENTO_API_URL}}"

    echo "🗑️  Removendo pipeline: $STREAM_ID"
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
        -X DELETE "$BENTO_URL/bento/streams/$STREAM_ID")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        echo "✅ Pipeline '$STREAM_ID' removido"
    else
        echo "⚠️  Resposta HTTP $HTTP_CODE ao remover pipeline"
    fi

#-----------------------------------------------------------------------------
# INSTALAÇÃO / DEPLOY
#-----------------------------------------------------------------------------

# Instala o serviço systemd (requer sudo)
install-service:
    sudo cp systemd/bento.service /etc/systemd/system/bento.service
    sudo systemctl daemon-reload
    sudo systemctl enable bento
    echo "✅ Serviço systemd instalado e habilitado"

# Atualiza o serviço em produção (git pull + restart)
deploy:
    git pull origin main
    just bento-restart
    echo "✅ Deploy concluído"
