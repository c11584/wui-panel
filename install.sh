#!/bin/bash

# WUI - One-Click Installation Script (All-in-one)
# https://github.com/c11584/wui

set -e

# Colors for output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m' # No Color

# Default configuration
PANEL_PORT=32451
PANEL_USER="admin"
PANEL_PASS="$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 16 2>/dev/null || head -c 16 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)"
INSTALL_DIR="/opt/wui"
WUI_VERSION="$(cat "$(dirname "$0")/../VERSION" 2>/dev/null | tr -d '[:space:]')"
# pipe 模式下没有本地 VERSION 文件，从 GitHub API 获取最新版本
if [[ -z "$WUI_VERSION" ]]; then
    WUI_VERSION="$(curl -sL https://api.github.com/repos/c11584/wui-panel/releases/latest 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
fi
[[ -z "$WUI_VERSION" ]] && WUI_VERSION="1.0.0"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PANEL_PORT="$2"
            shift 2
            ;;
        --username)
            PANEL_USER="$2"
            shift 2
            ;;
        --password)
            PANEL_PASS="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT          Panel port (default: 32451)"
            echo "  --username USER      Admin username (default: admin)"
            echo "  --password PASS      Admin password (default: random)"
            echo "  --install-dir DIR    Installation directory (default: /opt/wui)"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Print banner
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Detect OS
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

# Install minimal dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update -y
            apt-get install -y curl wget unzip
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y curl wget unzip
            ;;
        fedora)
            dnf install -y curl wget unzip
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm curl wget unzip
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Dependencies installed${NC}"
}

# Download and install WUI (all-in-one package)
install_wui() {
    echo -e "${YELLOW}Installing WUI panel...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            WUI_ARCH="amd64"
            ;;
        aarch64|arm64)
            WUI_ARCH="arm64"
            ;;
        armv7l|armhf)
            WUI_ARCH="arm"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # Download all-in-one package (public repo: wui-panel)
    WUI_URL="https://github.com/c11584/wui-panel/releases/download/v${WUI_VERSION}/wui-${WUI_VERSION}-linux-${WUI_ARCH}.tar.gz"
    TMP_DIR="/tmp/wui-$$"
    
    mkdir -p $TMP_DIR
    
    # Try to download, fallback to local for testing
    if ! wget --timeout=30 --tries=3 -O $TMP_DIR/wui.tar.gz $WUI_URL 2>/dev/null; then
        echo -e "${YELLOW}Pre-built package not found, checking for local files...${NC}"
        if [[ -f "./wui-linux-${WUI_ARCH}-${WUI_VERSION}.tar.gz" ]]; then
            cp ./wui-linux-${WUI_ARCH}-${WUI_VERSION}.tar.gz $TMP_DIR/wui.tar.gz
        elif [[ -f "./wui" && -d "./web" ]]; then
            # Local development files
            echo -e "${YELLOW}Using local development files${NC}"
            mkdir -p $INSTALL_DIR
            cp -r ./web $INSTALL_DIR/
            cp ./wui $INSTALL_DIR/
            mkdir -p $INSTALL_DIR/bin
            chmod +x $INSTALL_DIR/wui
            mkdir -p $INSTALL_DIR/{data,logs,configs}
            rm -rf $TMP_DIR
            echo -e "${GREEN}WUI panel installed from local files${NC}"
            return
        else
            echo -e "${RED}WUI package not found. Please download it first.${NC}"
            exit 1
        fi
    fi
    
    # Extract package
    tar -xzf $TMP_DIR/wui.tar.gz -C $TMP_DIR
    
    # Find extracted directory (top-level dir from tar)
    EXTRACTED_DIR=$(tar -tzf $TMP_DIR/wui.tar.gz | head -1 | cut -d'/' -f1)
    EXTRACTED_DIR="$TMP_DIR/$EXTRACTED_DIR"
    
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        echo -e "${RED}Failed to extract package${NC}"
        exit 1
    fi
    
    # Install
    mkdir -p $INSTALL_DIR
    cp -r $EXTRACTED_DIR/* $INSTALL_DIR/
    chmod +x $INSTALL_DIR/wui-server
    chmod +x $INSTALL_DIR/bin/xray 2>/dev/null || true
    
    # Create necessary directories
    mkdir -p $INSTALL_DIR/{data,logs,configs}
    
    # Cleanup
    rm -rf $TMP_DIR
    
    echo -e "${GREEN}WUI panel installed${NC}"
}

# Download Xray binary
download_xray() {
    echo -e "${YELLOW}Downloading Xray core...${NC}"
    
    # Check if xray already exists
    if [[ -f "$INSTALL_DIR/bin/xray" ]]; then
        echo -e "${GREEN}Xray already installed, skipping download${NC}"
        return
    fi
    
    # Get latest Xray version
    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*//')
    
    if [[ -z "$XRAY_VERSION" ]]; then
        XRAY_VERSION="25.3.6"  # Fallback version
    fi
    
    echo -e "${GREEN}Xray version: $XRAY_VERSION${NC}"
    
    # Detect architecture for Xray
    case $ARCH in
        x86_64)
            XRAY_ARCH="64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="arm64-v8a"
            ;;
        armv7l|armhf)
            XRAY_ARCH="arm32-v7a"
            ;;
        *)
            echo -e "${RED}Unsupported architecture for Xray: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"
    
    mkdir -p $INSTALL_DIR/bin
    TMP_XRAY="/tmp/xray-$$"
    mkdir -p $TMP_XRAY
    
    if wget -O $TMP_XRAY/xray.zip $XRAY_URL 2>/dev/null; then
        unzip -o $TMP_XRAY/xray.zip -d $TMP_XRAY
        mv $TMP_XRAY/xray $INSTALL_DIR/bin/xray
        chmod +x $INSTALL_DIR/bin/xray
        echo -e "${GREEN}Xray core installed${NC}"
    else
        echo -e "${YELLOW}Failed to download Xray, you may need to install it manually${NC}"
    fi
    
    rm -rf $TMP_XRAY
}

# Create configuration
create_config() {
    # 如果已有 config.json（升级安装），保留原有配置
    if [[ -f "$INSTALL_DIR/config.json" ]]; then
        echo -e "${GREEN}Configuration preserved (existing config found)${NC}"
        # 从已有配置读取端口和密码，用于后续显示
        PANEL_PORT=$(grep -o '"port":[[:space:]]*[0-9]*' "$INSTALL_DIR/config.json" | grep -o '[0-9]*$' || echo "$PANEL_PORT")
        PANEL_USER=$(grep -o '"username":[[:space:]]*"[^"]*"' "$INSTALL_DIR/config.json" | grep -o '"[^"]*"$' | tr -d '"' || echo "$PANEL_USER")
        PANEL_PASS=$(grep -o '"password":[[:space:]]*"[^"]*"' "$INSTALL_DIR/config.json" | grep -o '"[^"]*"$' | tr -d '"' || echo "$PANEL_PASS")
        return
    fi

    echo -e "${YELLOW}Creating configuration...${NC}"
    
    cat > $INSTALL_DIR/config.json << CONFIG
{
  "panel": {
    "port": $PANEL_PORT,
    "username": "$PANEL_USER",
    "password": "$PANEL_PASS"
  },
  "xray": {
    "binPath": "$INSTALL_DIR/bin/xray",
    "configPath": "$INSTALL_DIR/configs"
  },
  "database": {
    "path": "$INSTALL_DIR/data/wui.db"
  },
  "logs": {
    "path": "$INSTALL_DIR/logs",
    "level": "info"
  },
  "license": {
    "serverUrl": "",
    "gracePeriodDays": 7
  }
}
CONFIG
    
    echo -e "${GREEN}Configuration created${NC}"
}

# Setup systemd service
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
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/wui-server
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable wui
    
    echo -e "${GREEN}Systemd service configured${NC}"
}

# Setup CLI command
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
    echo -e "${GREEN}CLI command installed: wui${NC}"
}

# Configure firewall
setup_firewall() {
    echo -e "${YELLOW}Configuring firewall...${NC}"
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $PANEL_PORT/tcp comment "WUI Panel"
        echo -e "${GREEN}UFW firewall configured${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp
        firewall-cmd --reload
        echo -e "${GREEN}Firewalld configured${NC}"
    else
        echo -e "${YELLOW}No firewall detected, skipping...${NC}"
    fi
}

# Start service
start_service() {
    echo -e "${YELLOW}Starting WUI service...${NC}"
    systemctl start wui
    
    # Wait for service to start
    sleep 2
    
    if systemctl is-active --quiet wui; then
        echo -e "${GREEN}WUI service started successfully${NC}"
    else
        echo -e "${RED}Failed to start WUI service${NC}"
        journalctl -u wui -n 20 --no-pager
        exit 1
    fi
}

# Initialize admin license
init_admin_license() {
    echo -e "${YELLOW}Initializing admin license...${NC}"
    
    cd $INSTALL_DIR
    ./wui-server --init-admin-license 2>&1 | tee /tmp/wui-admin-license.txt
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Admin license initialized${NC}"
        echo -e "${YELLOW}Admin License Key has been saved to /tmp/wui-admin-license.txt${NC}"
    else
        echo -e "${YELLOW}Admin license initialization skipped (may already exist)${NC}"
    fi
}

# Show success message
show_success() {
    SERVER_IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
    
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}WUI Installation Complete!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo -e "${BLUE}Panel URL:${NC} http://$SERVER_IP:$PANEL_PORT"
    echo -e "${BLUE}Username:${NC}  $PANEL_USER"
    echo -e "${BLUE}Password:${NC}  $PANEL_PASS"
    echo ""
    echo -e "${YELLOW}Installation Directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "  - The panel runs in AGENT mode by default"
    echo "  - An admin license has been generated for you"
    echo "  - Check /tmp/wui-admin-license.txt for your license key"
    echo "  - Go to Settings > License to activate"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  wui start       Start WUI"
    echo "  wui stop        Stop WUI"
    echo "  wui restart     Restart WUI"
    echo "  wui status      Show service status"
    echo "  wui log [-f]    Show logs (add -f to follow)"
    echo "  wui version     Show version"
    echo "  wui uninstall   Uninstall WUI"
    echo ""
    echo -e "${RED}IMPORTANT: A random password has been generated. Please save it now!${NC}"
    echo -e "${RED}           Run 'echo $PANEL_PASS' to view it again.${NC}"
    echo ""
}

# Main installation process
main() {
    print_banner
    
    echo -e "${YELLOW}Installation Configuration:${NC}"
    echo "  Port:         $PANEL_PORT"
    echo "  Username:     $PANEL_USER"
    echo "  Password:     $PANEL_PASS"
    echo "  Install Dir:  $INSTALL_DIR"
    echo ""
    
    # pipe/curl 模式（stdin 不是终端）跳过确认
    if tty -s 2>/dev/null; then
        read -p "Continue with installation? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 1
        fi
    else
        echo "Non-interactive mode, proceeding..."
    fi
   
    check_root
    detect_os
    install_dependencies
    install_wui
    download_xray
    create_config
    setup_service
    setup_cli
    setup_firewall
    start_service
    init_admin_license
    show_success
}

# Run main function
main
