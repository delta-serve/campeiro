#!/bin/bash
# setup.sh - Script de instalação simplificado do Bento Project
# Execute com: sudo bash setup.sh

set -e  # Parar em caso de erro

#=============================================================================
# CONFIGURAÇÕES
#=============================================================================

PROJECT_NAME="ds-bento-streams"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR"
SERVICE_USER="bento"
SERVICE_NAME="bento"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'&limit=${COUCHDB_LIMIT}
NC='\033[0m' # No Color

#=============================================================================
# FUNÇÕES AUXILIARES
#=============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_note() {
    echo -e "${BLUE}[NOTE]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root (sudo)"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#=============================================================================
# VERIFICAÇÕES PRÉ-INSTALAÇÃO
#=============================================================================

check_prerequisites() {
    log_info "Verificando pré-requisitos..."
    
    # Verificar se está no diretório correto
    if [[ ! -f "$PROJECT_PATH/setup.sh" ]]; then
        log_error "Execute este script do diretório do projeto"
        exit 1
    fi
    
    # Verificar comandos necessários
    local missing_cmds=()
    for cmd in curl tar systemctl; do
        if ! command_exists "$cmd"; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [ ${#missing_cmds[@]} -gt 0 ]; then
        log_error "Comandos faltando: ${missing_cmds[*]}"
        exit 1
    fi
    
    log_info "✓ Pré-requisitos OK"
}

#=============================================================================
# INSTALAÇÃO DO BENTO
#=============================================================================

install_bento() {
    log_info "Verificando instalação do Bento..."
    
    if command_exists bento; then
        local version=$(bento --version 2>&1 | head -1)
        log_info "✓ Bento já instalado: $version"
        return 0
    fi
    
    log_info "Instalando Bento..."
    curl -Lsf https://warpstreamlabs.github.io/bento/sh/install | bash
    
    # Adicionar /usr/local/bin ao PATH da sessão atual
    export PATH="/usr/local/bin:$PATH"
    
    # Verificar novamente após adicionar ao PATH
    if command_exists bento; then
        local version=$(bento --version 2>&1 | head -1)
        log_info "✓ Bento instalado com sucesso: $version"
    elif [ -f /usr/local/bin/bento ]; then
        # Bento existe mas não está no PATH
        log_info "✓ Bento instalado em /usr/local/bin/bento"
        log_warn "Execute: export PATH=\"/usr/local/bin:\$PATH\" ou reinicie o terminal"
    else
        log_error "Falha ao instalar Bento"
        exit 1
    fi
}


#=============================================================================
# VERIFICAÇÃO DE DEPENDÊNCIAS EXTERNAS
#=============================================================================

check_dependencies() {
    log_info "Verificando dependências externas..."
    
    # Verificar Redis
    if command_exists redis-server || command_exists redis-cli; then
        log_info "✓ Redis encontrado"
        if systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null; then
            log_info "✓ Redis está rodando"
        else
            log_warn "Redis instalado mas não está rodando"
            log_note "Inicie com: sudo systemctl start redis-server (ou redis)"
        fi
    else
        log_warn "Redis não encontrado"
        log_note "Se seus streams usarem cache Redis, instale com:"
        log_note "  Ubuntu/Debian: sudo apt-get install redis-server"
        log_note "  CentOS/RHEL:   sudo yum install redis"
    fi
}

#=============================================================================
# CONFIGURAÇÃO DE USUÁRIO E PERMISSÕES
#=============================================================================

setup_user() {
    log_info "Configurando usuário do serviço..."
    
    if id "$SERVICE_USER" &>/dev/null; then
        log_info "✓ Usuário $SERVICE_USER já existe"
    else
        log_info "Criando usuário $SERVICE_USER..."
        useradd -r -s /bin/false -d "$PROJECT_PATH" "$SERVICE_USER"
        log_info "✓ Usuário $SERVICE_USER criado"
    fi
}

setup_permissions() {
    log_info "Configurando permissões..."
    
    # Criar diretórios que não existem
    mkdir -p "$PROJECT_PATH/data"
    mkdir -p "$PROJECT_PATH/logs"
    mkdir -p "$PROJECT_PATH/config/resources"
    
    # Ajustar permissões
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_PATH"
    chmod 755 "$PROJECT_PATH"
    chmod 755 "$PROJECT_PATH/config"
    chmod 755 "$PROJECT_PATH/streams"
    chmod 755 "$PROJECT_PATH/data"
    chmod 755 "$PROJECT_PATH/logs"
    
    # Configurações devem ser legíveis mas não graváveis pelo serviço
    find "$PROJECT_PATH/config" -type f -exec chmod 644 {} \;
    find "$PROJECT_PATH/streams" -type f -exec chmod 644 {} \;
    
    # .env deve ser protegido
    if [ -f "$PROJECT_PATH/config/.env" ]; then
        chmod 600 "$PROJECT_PATH/config/.env"
    fi
    
    # Scripts executáveis
    chmod +x "$PROJECT_PATH/setup.sh" 2>/dev/null || true
    chmod +x "$PROJECT_PATH/update.sh" 2>/dev/null || true
    chmod +x "$PROJECT_PATH/scripts"/*.sh 2>/dev/null || true
    
    log_info "✓ Permissões configuradas"
}

#=============================================================================
# CONFIGURAÇÃO DE ARQUIVOS
#=============================================================================

setup_env_file() {
    log_info "Configurando arquivo de environment..."
    
    if [ ! -f "$PROJECT_PATH/config/.env" ]; then
        if [ -f "$PROJECT_PATH/config/.env.example" ]; then
            log_info "Criando .env a partir do .env.example..."
            cp "$PROJECT_PATH/config/.env.example" "$PROJECT_PATH/config/.env"
            chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_PATH/config/.env"
            chmod 600 "$PROJECT_PATH/config/.env"
            log_warn "⚠ Edite $PROJECT_PATH/config/.env com suas configurações"
        else
            log_info "Criando .env padrão..."
            cat > "$PROJECT_PATH/config/.env" <<'EOF'
# Bento Environment Variables
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
BENTO_HTTP_PORT=10083
LOG_LEVEL=INFO
APP_ENVIRONMENT=production
EOF
            chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_PATH/config/.env"
            chmod 600 "$PROJECT_PATH/config/.env"
        fi
    else
        log_info "✓ Arquivo .env já existe"
    fi
}

#=============================================================================
# CONFIGURAÇÃO DO SYSTEMD
#=============================================================================

setup_systemd() {
    log_info "Configurando serviço systemd..."
    
    local service_file="/etc/systemd/system/$SERVICE_NAME.service"
    
    # Usar template se existir, senão criar um padrão
    if [ -f "$PROJECT_PATH/systemd/bento.service.template" ]; then
        log_info "Usando template do systemd..."
        sed "s|PROJECT_PATH|$PROJECT_PATH|g" \
            "$PROJECT_PATH/systemd/bento.service.template" > "$service_file"
    else
        log_info "Criando arquivo de serviço systemd..."
        cat > "$service_file" <<EOF
[Unit]
Description=Bento Stream Processor (Streams Mode)
Documentation=https://warpstreamlabs.github.io/bento/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_PATH

ExecStart=/usr/local/bin/bento \\
  --env-file config/.env \\
  -c config/service.yaml \\
  -r config/resources/*.yaml \\
  streams streams/*.yaml

Restart=always
RestartSec=10s

TimeoutStartSec=60s
TimeoutStopSec=30s

LimitNOFILE=65536
LimitNPROC=4096

StandardOutput=journal
StandardError=journal
SyslogIdentifier=bento

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    log_info "✓ Arquivo de serviço criado em $service_file"
}


enable_service() {
    log_info "Habilitando e iniciando serviço..."
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_info "Iniciando serviço..."
    if systemctl start "$SERVICE_NAME"; then
        log_info "✓ Serviço iniciado com sucesso"
    else
        log_error "Falha ao iniciar serviço. Verifique os logs:"
        log_error "  sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

#=============================================================================
# VALIDAÇÃO
#=============================================================================

validate_installation() {
    log_info "Validando instalação..."
    
    # Aguardar alguns segundos para o serviço inicializar
    sleep 3
    
    # Verificar status do serviço
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "✓ Serviço está rodando"
    else
        log_error "Serviço não está rodando"
        return 1
    fi
    
    # Verificar API
    if curl -sf http://localhost:4195/ping > /dev/null 2>&1; then
        log_info "✓ API respondendo"
    else
        log_warn "⚠ API não está respondendo"
    fi
    
    # Listar streams
    local streams=$(curl -s http://localhost:4195/streams 2>/dev/null)
    if [ -n "$streams" ]; then
        log_info "✓ Streams carregados:"
        echo "$streams" | jq -r 'keys[]' 2>/dev/null || echo "$streams"
    fi
}

#=============================================================================
# MAIN
#=============================================================================

main() {
    echo "=============================================="
    echo "  Bento Project Setup"
    echo "=============================================="
    echo ""
    
    check_root
    check_prerequisites
    
    install_bento
    check_dependencies
    
    setup_user
    setup_permissions
    setup_env_file
    
    setup_systemd
    enable_service
    
    validate_installation
    
    echo ""
    echo "=============================================="
    log_info "Setup concluído com sucesso!"
    echo "=============================================="
    echo ""
    echo "Comandos úteis:"
    echo "  Status:     sudo systemctl status $SERVICE_NAME"
    echo "  Logs:       sudo journalctl -u $SERVICE_NAME -f"
    echo "  Restart:    sudo systemctl restart $SERVICE_NAME"
    echo "  Streams:    curl http://localhost:4195/streams"
    echo "  Métricas:   curl http://localhost:4195/metrics"
    echo ""
    echo "Arquivos importantes:"
    echo "  Projeto:    $PROJECT_PATH"
    echo "  Config:     $PROJECT_PATH/config/service.yaml"
    echo "  Streams:    $PROJECT_PATH/streams/"
    echo "  Env:        $PROJECT_PATH/config/.env"
    echo ""
    
    # Nota sobre Redis se não estiver instalado
    if ! command_exists redis-server && ! command_exists redis-cli; then
        echo ""
        log_note "NOTA: Redis não está instalado neste sistema."
        log_note "Se seus streams utilizarem cache Redis, instale-o manualmente:"
        log_note "  Ubuntu/Debian: sudo apt-get install redis-server"
        log_note "  CentOS/RHEL:   sudo yum install redis"
        echo ""
    fi
}

# Executar
main "$@"
