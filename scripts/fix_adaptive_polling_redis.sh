#!/bin/bash
# Script para limpar chaves corrompidas do Redis relacionadas ao adaptive polling
# Criado em: 2026-03-05
# Propósito: Remover chaves que contêm a string "null" que causam erros no adaptive polling

set -euo pipefail

# Configuração
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PREFIX="${REDIS_PREFIX:-bento_streams__}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se redis-cli está disponível
if ! command -v redis-cli &> /dev/null; then
    log_error "redis-cli não encontrado. Instale o pacote redis-tools."
    exit 1
fi

# Testa conexão com Redis
if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" PING &> /dev/null; then
    log_error "Não foi possível conectar ao Redis em $REDIS_HOST:$REDIS_PORT"
    exit 1
fi

log_info "Conectado ao Redis em $REDIS_HOST:$REDIS_PORT"
log_info "Procurando chaves corrompidas com prefixo: $REDIS_PREFIX"

# Lista de chaves a serem verificadas e limpas
KEYS=(
    "${REDIS_PREFIX}bcpf_backoff_secs"
    "${REDIS_PREFIX}bcpf_backoff_until"
    "${REDIS_PREFIX}bcnpj_backoff_secs"
    "${REDIS_PREFIX}bcnpj_backoff_until"
)

CLEANED=0
TOTAL=0

# Processa cada chave
for KEY in "${KEYS[@]}"; do
    TOTAL=$((TOTAL + 1))
    
    # Verifica se a chave existe
    if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" EXISTS "$KEY" | grep -q "1"; then
        log_info "Chave não existe (OK): $KEY"
        continue
    fi
    
    # Lê o valor da chave
    VALUE=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" GET "$KEY")
    
    # Verifica se o valor é "null" ou está vazio/inválido
    if [[ "$VALUE" == "null" ]] || [[ -z "$VALUE" ]] || ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
        log_warn "Chave corrompida encontrada: $KEY (valor: '$VALUE')"
        
        # Delete a chave
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" DEL "$KEY" &> /dev/null; then
            log_info "✓ Chave removida: $KEY"
            CLEANED=$((CLEANED + 1))
        else
            log_error "✗ Falha ao remover: $KEY"
        fi
    else
        log_info "Chave válida (mantida): $KEY (valor: $VALUE)"
    fi
done

# Resumo
echo ""
log_info "========================================="
log_info "Resumo da limpeza:"
log_info "  Total de chaves verificadas: $TOTAL"
log_info "  Chaves corrompidas removidas: $CLEANED"
log_info "========================================="
echo ""

if [ "$CLEANED" -gt 0 ]; then
    log_info "As chaves corrompidas foram removidas com sucesso."
    log_info "O Bento Streams irá recriá-las automaticamente com valores válidos."
    log_info "Recomendação: Reinicie o serviço bento para aplicar as mudanças imediatamente:"
    echo ""
    echo "    sudo systemctl restart bento"
    echo ""
else
    log_info "Nenhuma chave corrompida foi encontrada. Sistema está limpo."
fi

exit 0
