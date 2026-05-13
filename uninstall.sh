#!/bin/bash

# WUI Uninstall Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/wui"

echo -e "${YELLOW}This will uninstall WUI from your system.${NC}"
read -p "Are you sure? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 1
fi

echo "Stopping WUI service..."
systemctl stop wui || true
systemctl disable wui || true

echo "Removing systemd service..."
rm -f /etc/systemd/system/wui.service
systemctl daemon-reload

# Remove firewall rules — read port from config if available
PORT=$(python3 -c "import json; print(json.load(open('${INSTALL_DIR}/config.json')).get('panel',{}).get('port',32451))" 2>/dev/null || echo "32451")
echo "Removing firewall rules (port ${PORT})..."
if command -v ufw >/dev/null 2>&1; then
    ufw delete allow ${PORT}/tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --remove-port=${PORT}/tcp || true
    firewall-cmd --reload || true
fi

echo "Removing installation directory..."
rm -rf $INSTALL_DIR

echo "Removing CLI command..."
rm -f /usr/local/bin/wui
rm -f /tmp/wui-admin-license.txt

echo -e "${GREEN}WUI has been uninstalled successfully.${NC}"
