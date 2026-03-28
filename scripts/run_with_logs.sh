#!/bin/bash

# Script para executar Bento com logs visíveis no servidor remoto
# Uso: ./run_with_logs.sh [bcadastros_bcpf|bcadastros_bcnpj]

STREAM_NAME=${1:-bcadastros_bcpf}
LOG_DIR="/var/log/bento-streams"
LOG_FILE="$LOG_DIR/bento-${STREAM_NAME}-$(date +%Y%m%d-%H%M%S).log"

# Criar diretório de logs se não existir
sudo mkdir -p "$LOG_DIR"
sudo chown $(whoami):$(whoami) "$LOG_DIR"

echo "Iniciando stream: $STREAM_NAME"
echo "Logs salvos em: $LOG_FILE"
echo "Para acompanhar em tempo real: tail -f $LOG_FILE"
echo ""

# Executar Bento com logs
bento \
    --log.level DEBUG \
    --env-file config/.env \
    -c config/service.yaml \
    -r config/resources/redis_cache.yaml \
    streams "streams/${STREAM_NAME}.yaml" \
    2>&1 | tee "$LOG_FILE"