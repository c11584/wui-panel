#!/bin/bash

# WUI - One-Click Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash
#        or: bash install.sh [--port PORT] [--username USER] [--password PASS] [--install-dir DIR]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub Release
GITHUB_REPO="c11584/wui-panel"

# 默认配置
PANEL_PORT=32451
PANEL_USER="admin"
PANEL_PASS="$(head -c 16 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)"
INSTALL_DIR="/opt/wui"


# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --port) PANEL_PORT="$2"; shift 2 ;;
        --username) PANEL_USER="$2"; shift 2 ;;
        --password) PANEL_PASS="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT            Panel port (default: 32451)"
            echo "  --username USER        Admin username (default: admin)"
            echo "  --password PASS        Admin password (default: random)"
            echo "  --install-dir DIR      Install directory (default: /opt/wui)"
            echo "  --help                 Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# ============================================================
# 函数
# ============================================================

print_banner() {
    echo -e "${BLUE}"
    cat << "BANNER"
██╗    ██╗██╗███╗   ██╗
██║    ██║██║████╗  ██║
██║ █╗ ██║██║██╔██╗ ██║
██║███╗██║██║██║╚██╗██║
╚███╔███╔╝██║██║ ╚████║
 ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝
BANNER
    echo -e "${NC}"
    echo -e "${GREEN}Next-Generation Proxy Management Panel${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
    echo -e "${GREEN}OS: $OS${NC}"
}

install_deps() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    case $OS in
        ubuntu|debian) apt-get update -y && apt-get install -y curl wget unzip ;;
        centos|rhel|rocky|almalinux) yum install -y curl wget unzip ;;
        fedora) dnf install -y curl wget unzip ;;
        arch|manjaro) pacman -Sy --noconfirm curl wget unzip ;;
        *) echo -e "${RED}Unsupported OS: $OS${NC}"; exit 1 ;;
    esac
    echo -e "${GREEN}Dependencies OK${NC}"
}

get_latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        echo -e "${RED}Failed to get latest version${NC}"
        exit 1
    fi
    echo "$version"
}

download_and_install() {
    echo -e "${YELLOW}Installing WUI panel...${NC}"

    # 架构
    case $(uname -m) in
        x86_64) WUI_ARCH="amd64" ;;
        aarch64|arm64) WUI_ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported arch: $(uname -m)${NC}"; exit 1 ;;
    esac

    # 版本
    WUI_VERSION=$(get_latest_version)
    echo -e "${GREEN}Version: v${WUI_VERSION} (${WUI_ARCH})${NC}"

    # 下载
    PACKAGE_NAME="wui-${WUI_VERSION}-linux-${WUI_ARCH}"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${WUI_VERSION}/${PACKAGE_NAME}.tar.gz"
    TMP_DIR="/tmp/wui-install-$$"
    mkdir -p "$TMP_DIR"

    echo -e "${YELLOW}Downloading ${PACKAGE_NAME}.tar.gz ...${NC}"
    if ! wget -q -O "$TMP_DIR/${PACKAGE_NAME}.tar.gz" "$DOWNLOAD_URL" 2>&1; then
        echo -e "${RED}Download failed${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    echo -e "${GREEN}Download OK ($(du -h "$TMP_DIR/${PACKAGE_NAME}.tar.gz" | cut -f1))${NC}"

    # 校验
    SHA256_URL="https://github.com/${GITHUB_REPO}/releases/download/v${WUI_VERSION}/${PACKAGE_NAME}.tar.gz.sha256"
    if wget -q -O "$TMP_DIR/${PACKAGE_NAME}.tar.gz.sha256" "$SHA256_URL" 2>/dev/null; then
        echo -e "${YELLOW}Verifying checksum...${NC}"
        (cd "$TMP_DIR" && sha256sum -c "${PACKAGE_NAME}.tar.gz.sha256")
        echo -e "${GREEN}Checksum OK${NC}"
    fi

    # 解压
    echo -e "${YELLOW}Extracting...${NC}"
    tar -xzf "$TMP_DIR/${PACKAGE_NAME}.tar.gz" -C "$TMP_DIR"

    # 安装
    mkdir -p "$INSTALL_DIR"
    cp -r "$TMP_DIR/${PACKAGE_NAME}"/* "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/wui-server" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bin/xray" 2>/dev/null || true
    mkdir -p "$INSTALL_DIR"/{data,logs,configs}

    # 清理
    rm -rf "$TMP_DIR"
    echo -e "${GREEN}Installed to ${INSTALL_DIR}${NC}"
}

create_config() {
    # 升级安装：保留已有配置，避免密码被覆盖
    if [[ -f "$INSTALL_DIR/config.json" ]]; then
        echo -e "${GREEN}Config OK (preserved existing)${NC}"
        PANEL_PORT=$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$INSTALL_DIR/config.json" | head -1)
        PANEL_USER=$(sed -n 's/.*"username"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$INSTALL_DIR/config.json" | head -1)
        PANEL_PASS=$(sed -n 's/.*"password"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$INSTALL_DIR/config.json" | head -1)
        return
    fi

    echo -e "${YELLOW}Creating config...${NC}"
    cat > "$INSTALL_DIR/config.json" << CONFIG
{
  "panel": {
    "port": ${PANEL_PORT},
    "username": "${PANEL_USER}",
    "password": "${PANEL_PASS}"
  },
  "xray": {
    "binPath": "${INSTALL_DIR}/bin/xray",
    "configPath": "${INSTALL_DIR}/configs"
  },
  "database": {
    "path": "${INSTALL_DIR}/data/wui.db"
  },
  "logs": {
    "path": "${INSTALL_DIR}/logs",
    "level": "info"
  },
  "license": {
    "gracePeriodDays": 7
  }
}
CONFIG
    echo -e "${GREEN}Config OK${NC}"
}

setup_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"
    cat > /etc/systemd/system/wui.service << SERVICE
[Unit]
Description=WUI - Proxy Management Panel
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/wui-server
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable wui
    echo -e "${GREEN}Service OK${NC}"
}

setup_cli() {
    echo -e "${YELLOW}Setting up CLI command...${NC}"
    cat > /usr/local/bin/wui << 'CLI'
#!/bin/bash
case "$1" in
    start)   systemctl start wui ;;
    stop)    systemctl stop wui ;;
    restart) systemctl restart wui ;;
    status)  systemctl status wui --no-pager ;;
    log|logs)
        if [ "$2" = "-f" ] || [ "$2" = "--follow" ]; then
            journalctl -u wui -f
        else
            journalctl -u wui -n 50 --no-pager
        fi ;;
    version)
        /opt/wui/wui-server -v 2>/dev/null || echo "unknown" ;;
    uninstall)
        echo -e "\033[31mThis will remove WUI completely. Type 'yes' to confirm:\033[0m"
        read -r confirm
        if [ "$confirm" = "yes" ]; then
            systemctl stop wui
            systemctl disable wui
            rm -f /etc/systemd/system/wui.service
            rm -f /usr/local/bin/wui
            rm -rf /opt/wui
            systemctl daemon-reload
            echo "WUI uninstalled."
        else
            echo "Cancelled."
        fi ;;
    *)
        echo "WUI - Proxy Management Panel"
        echo ""
        echo "Usage: wui <command>"
        echo ""
        echo "Commands:"
        echo "  start       Start WUI"
        echo "  stop        Stop WUI"
        echo "  restart     Restart WUI"
        echo "  status      Show service status"
        echo "  log [-f]    Show logs (add -f to follow)"
        echo "  version     Show version"
        echo "  uninstall   Uninstall WUI"
        ;;
esac
CLI
    chmod +x /usr/local/bin/wui
    echo -e "${GREEN}CLI OK (wui start|stop|restart|status|log)${NC}"
}

setup_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$PANEL_PORT"/tcp comment "WUI Panel" 2>/dev/null
        echo -e "${GREEN}UFW: port ${PANEL_PORT} opened${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$PANEL_PORT"/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        echo -e "${GREEN}Firewalld: port ${PANEL_PORT} opened${NC}"
    fi
}

start_service() {
    echo -e "${YELLOW}Starting WUI...${NC}"
    systemctl start wui
    sleep 3

    if systemctl is-active --quiet wui; then
        echo -e "${GREEN}WUI started${NC}"
    else
        echo -e "${RED}Failed to start:${NC}"
        journalctl -u wui -n 30 --no-pager
        exit 1
    fi
}

show_success() {
    SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  WUI Installation Complete!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo -e "${BLUE}  URL:${NC}      http://${SERVER_IP}:${PANEL_PORT}"
    echo -e "${BLUE}  User:${NC}     ${PANEL_USER}"
    echo -e "${BLUE}  Pass:${NC}     ${PANEL_PASS}"
    echo ""
    echo -e "${YELLOW}  Dir:${NC}      ${INSTALL_DIR}"
    echo ""
    echo "  wui start|stop|restart|status|log"
    echo ""
    echo -e "${RED}  Save the password above!${NC}"
    echo ""
}

# ============================================================
# 主流程
# ============================================================

print_banner
echo -e "${YELLOW}Config:${NC}  port=${PANEL_PORT}  dir=${INSTALL_DIR}  user=${PANEL_USER}"
echo ""

check_root
detect_os
install_deps
download_and_install
create_config
setup_service
setup_cli
setup_firewall
start_service
show_success
