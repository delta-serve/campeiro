#!/bin/bash
# update.sh - Script para atualizar o projeto via Git

set -e

PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="bento"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "=============================================="
echo "  Bento Project Update"
echo "=============================================="
echo ""

cd "$PROJECT_PATH"

# Verificar se usuário está no grupo dev-admins
if ! groups | grep -q dev-admins; then
    log_warn "Você não está no grupo dev-admins"
    log_warn "Entre novamente no servidor para atualizar os grupos"
    exit 1
fi

# Verificar mudanças locais
if [[ -n $(git status -s 2>/dev/null) ]]; then
    log_warn "Existem mudanças locais não commitadas:"
    git status -s
    echo ""
    log_warn "Deseja continuar? Mudanças locais podem ser perdidas. (s/n)"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_info "Atualização cancelada"
        exit 0
    fi
fi

# Fazer stash se necessário
if [[ -n $(git status -s 2>/dev/null) ]]; then
    log_info "Salvando mudanças locais (stash)..."
    git stash
fi

# Atualizar código
log_info "Atualizando código do Git..."
git pull

# Validar configurações
log_info "Validando configurações..."
if bento --env-file config/.env lint -c config/service.yaml; then
    log_info "✓ Configuração geral válida"
else
    log_warn "⚠ Erro na configuração geral"
    exit 1
fi

if bento --env-file config/.env lint streams streams/*.yaml 2>/dev/null; then
    log_info "✓ Streams válidos"
else
    log_warn "⚠ Erro em streams"
fi

# Reiniciar serviço (requer sudo apenas para restart)
log_info "Reiniciando serviço (requer sudo)..."
sudo systemctl restart "$SERVICE_NAME"

# Aguardar inicialização
sleep 3

# Verificar status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_info "✓ Serviço reiniciado com sucesso"
else
    log_warn "⚠ Serviço não está rodando. Verifique os logs:"
    echo "  sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

echo ""
echo "=============================================="
log_info "Atualização concluída!"
echo "=============================================="
echo ""
echo "Ver logs: sudo journalctl -u $SERVICE_NAME -f"
echo "Ver streams: curl http://localhost:4195/streams"
