#!/bin/bash

# WUI - One-Click Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash
#        or: curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash -s -- --port 8080

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# GitHub Release 仓库
GITHUB_REPO="c11584/wui-panel"

# 默认配置
PANEL_PORT=32451
PANEL_USER="admin"
PANEL_PASS="$(head -c 16 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)"
INSTALL_DIR="/opt/wui"
LICENSE_SERVER=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --port) PANEL_PORT="$2"; shift 2 ;;
        --username) PANEL_USER="$2"; shift 2 ;;
        --password) PANEL_PASS="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --license-server) LICENSE_SERVER="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT            Panel port (default: 32451)"
            echo "  --username USER        Admin username (default: admin)"
            echo "  --password PASS        Admin password (default: random)"
            echo "  --install-dir DIR      Install directory (default: /opt/wui)"
            echo "  --license-server URL   License server URL"
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
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
    echo -e "${GREEN}Detected OS: $OS $VER${NC}"
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
    echo -e "${GREEN}Dependencies installed${NC}"
}

# 获取最新版本号
get_latest_version() {
    local version
    version=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        echo -e "${RED}Failed to get latest version from GitHub${NC}"
        exit 1
    fi
    echo "$version"
}

# 下载并安装 WUI 面板
install_wui() {
    echo -e "${YELLOW}Installing WUI panel...${NC}"

    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) WUI_ARCH="amd64" ;;
        aarch64|arm64) WUI_ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac

    # 获取版本
    WUI_VERSION=$(get_latest_version)
    echo -e "${GREEN}Latest version: v${WUI_VERSION}${NC}"

    # 下载
    PACKAGE_NAME="wui-${WUI_VERSION}-linux-${WUI_ARCH}"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${WUI_VERSION}/${PACKAGE_NAME}.tar.gz"
    TMP_DIR="/tmp/wui-install-$$"

    mkdir -p "$TMP_DIR"
    echo -e "${YELLOW}Downloading ${PACKAGE_NAME}.tar.gz...${NC}"

    if ! wget -O "$TMP_DIR/wui.tar.gz" "$DOWNLOAD_URL" 2>&1; then
        echo -e "${RED}Download failed from: ${DOWNLOAD_URL}${NC}"
        echo -e "${YELLOW}Trying GitHub proxy...${NC}"
        # 尝试常见代理
        PROXY_URL="https://ghfast.top/${DOWNLOAD_URL}"
        if ! wget -O "$TMP_DIR/wui.tar.gz" "$PROXY_URL" 2>&1; then
            echo -e "${RED}All download attempts failed${NC}"
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi

    # 校验 sha256 (如果有的话)
    SHA256_URL="https://github.com/${GITHUB_REPO}/releases/download/v${WUI_VERSION}/${PACKAGE_NAME}.tar.gz.sha256"
    if wget -O "$TMP_DIR/wui.tar.gz.sha256" "$SHA256_URL" 2>/dev/null; then
        echo -e "${YELLOW}Verifying checksum...${NC}"
        cd "$TMP_DIR"
        sha256sum -c wui.tar.gz.sha256 || {
            echo -e "${RED}Checksum verification failed!${NC}"
            rm -rf "$TMP_DIR"
            exit 1
        }
        cd - > /dev/null
        echo -e "${GREEN}Checksum OK${NC}"
    fi

    # 解压
    tar -xzf "$TMP_DIR/wui.tar.gz" -C "$TMP_DIR"
    EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "wui-*" | head -1)

    # 安装
    mkdir -p "$INSTALL_DIR"
    cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/wui-server"
    chmod +x "$INSTALL_DIR/bin/xray" 2>/dev/null || true
    mkdir -p "$INSTALL_DIR"/{data,logs,configs}

    rm -rf "$TMP_DIR"
    echo -e "${GREEN}WUI panel installed to ${INSTALL_DIR}${NC}"
}

# 如果包里没带 Xray，单独下载
download_xray() {
    if [[ -f "$INSTALL_DIR/bin/xray" ]]; then
        echo -e "${GREEN}Xray already included in package${NC}"
        return
    fi

    echo -e "${YELLOW}Downloading Xray core...${NC}"
    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    [[ -z "$XRAY_VERSION" ]] && XRAY_VERSION="25.3.6"

    case $(uname -m) in
        x86_64) XRAY_ARCH="64" ;;
        aarch64|arm64) XRAY_ARCH="arm64-v8a" ;;
        *) echo -e "${YELLOW}Skipping Xray download${NC}"; return ;;
    esac

    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"
    TMP_XRAY="/tmp/xray-$$"
    mkdir -p "$TMP_XRAY" "$INSTALL_DIR/bin"

    if wget -O "$TMP_XRAY/xray.zip" "$XRAY_URL" 2>/dev/null; then
        unzip -o "$TMP_XRAY/xray.zip" -d "$TMP_XRAY"
        mv "$TMP_XRAY/xray" "$INSTALL_DIR/bin/xray"
        chmod +x "$INSTALL_DIR/bin/xray"
        echo -e "${GREEN}Xray v${XRAY_VERSION} installed${NC}"
    else
        echo -e "${YELLOW}Xray download failed, install manually${NC}"
    fi
    rm -rf "$TMP_XRAY"
}

# 生成配置文件
create_config() {
    echo -e "${YELLOW}Creating configuration...${NC}"

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
    "serverUrl": "${LICENSE_SERVER}",
    "gracePeriodDays": 7
  }
}
CONFIG

    echo -e "${GREEN}Configuration created${NC}"
}

# systemd 服务
setup_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"

    cat > /etc/systemd/system/wui.service << SERVICE
[Unit]
Description=WUI - Next-Generation Proxy Management Panel
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
    echo -e "${GREEN}Systemd service configured${NC}"
}

# 防火墙
setup_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$PANEL_PORT"/tcp comment "WUI Panel" 2>/dev/null
        echo -e "${GREEN}UFW: port ${PANEL_PORT} opened${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$PANEL_PORT"/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        echo -e "${GREEN}Firewalld: port ${PANEL_PORT} opened${NC}"
    else
        echo -e "${YELLOW}No firewall detected, skipping${NC}"
    fi
}

# 启动
start_service() {
    echo -e "${YELLOW}Starting WUI service...${NC}"
    systemctl start wui
    sleep 2

    if systemctl is-active --quiet wui; then
        echo -e "${GREEN}WUI service started${NC}"
    else
        echo -e "${RED}Failed to start WUI service${NC}"
        journalctl -u wui -n 20 --no-pager
        exit 1
    fi
}

show_success() {
    SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me || echo "YOUR_SERVER_IP")

    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}WUI Installation Complete!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo -e "${BLUE}Panel URL:${NC} http://${SERVER_IP}:${PANEL_PORT}"
    echo -e "${BLUE}Username:${NC}  ${PANEL_USER}"
    echo -e "${BLUE}Password:${NC}  ${PANEL_PASS}"
    echo ""
    echo -e "${YELLOW}Install Dir:${NC} ${INSTALL_DIR}"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  Start:   systemctl start wui"
    echo "  Stop:    systemctl stop wui"
    echo "  Restart: systemctl restart wui"
    echo "  Status:  systemctl status wui"
    echo "  Logs:    journalctl -u wui -f"
    echo ""
    echo -e "${RED}IMPORTANT: Save the password above!${NC}"
    echo ""
}

# ============================================================
# 主流程
# ============================================================

main() {
    print_banner

    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Port:           ${PANEL_PORT}"
    echo "  Username:       ${PANEL_USER}"
    echo "  Install Dir:    ${INSTALL_DIR}"
    echo "  License Server: ${LICENSE_SERVER:-not set}"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Cancelled" && exit 1

    check_root
    detect_os
    install_deps
    install_wui
    download_xray
    create_config
    setup_service
    setup_firewall
    start_service
    show_success
}

main
