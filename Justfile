set dotenv-load := true
export BENTO_ENV := "config/.env"

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
# BENTO (Redpanda Connect)
#-----------------------------------------------------------------------------

# Inicia o serviço do Bento
bento-start:
    sudo systemctl start bento

# Reinicia o serviço do Bento (útil para recarregar as configurações)
bento-restart: bento-lint
    sudo systemctl restart bento

# Recarrega os pipelines (atalho para reiniciar, já que é como o bento no systemd aplica as mudanças)
bento-reload: bento-restart

# Para o serviço do Bento
bento-stop:
    sudo systemctl stop bento

# Verifica e acompanha os logs do Bento
bento-logs lines="50":
    sudo journalctl -u bento -n {{lines}} -f

# Verifica o status atual do serviço
bento-status:
    sudo systemctl status bento

# Valida os arquivos de configuração e streams
bento-lint:
    bento --env-file config/.env lint -c config/service.yaml
    bento --env-file config/.env lint streams streams/*.yaml
