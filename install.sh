#!/bin/bash

# ============================================
#  Dilshan X-UI — One-Click Installer
#  Advanced Xray Management Panel
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║        🛡️  Dilshan X-UI Installer        ║"
echo "║     Advanced Xray Management Panel       ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Please run as root: sudo bash install.sh${NC}"
   exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS=$ID
else
    echo -e "${RED}❌ Unsupported OS${NC}"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="armv7" ;;
    *)
        echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
        exit 1
    ;;
esac

echo -e "${GREEN}✓ OS: $OS | Arch: $ARCH${NC}"

# Install dependencies
echo -e "\n${CYAN}📦 Installing dependencies...${NC}"
if command -v apt-get &> /dev/null; then
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget curl tar > /dev/null 2>&1
elif command -v yum &> /dev/null; then
    yum install -y wget curl tar > /dev/null 2>&1
fi

# Variables
REPO="vishwa7502/dilshan-ui"
INSTALL_DIR="/usr/local/dilshan-x-ui"
SERVICE_NAME="dilshan-x-ui"
CONFIG_DIR="/etc/dilshan-x-ui"

# Stop existing service
if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    echo -e "${YELLOW}⏹ Stopping existing service...${NC}"
    systemctl stop $SERVICE_NAME
fi

# Download latest release
echo -e "${CYAN}⬇️  Downloading Dilshan X-UI...${NC}"
LATEST_URL="https://github.com/$REPO/releases/latest/download/dilshan-x-ui-linux-${ARCH}.tar.gz"

# Fallback: clone and build from source
download_release() {
    cd /tmp
    if wget -q --show-progress "$LATEST_URL" -O dilshan-x-ui.tar.gz 2>/dev/null; then
        echo -e "${GREEN}✓ Downloaded release package${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No release found, building from source...${NC}"
        build_from_source
        return $?
    fi
}

build_from_source() {
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo -e "${CYAN}📦 Installing Go...${NC}"
        GO_VERSION="1.23.0"
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O /tmp/go.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        rm /tmp/go.tar.gz
    fi

    echo -e "${CYAN}🔨 Building from source...${NC}"
    cd /tmp
    rm -rf dilshan-ui-src
    git clone https://github.com/$REPO.git dilshan-ui-src
    cd dilshan-ui-src
    
    CGO_ENABLED=0 go build -o dilshan-x-ui -ldflags="-s -w" 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi

    # Package it
    mkdir -p /tmp/dilshan-x-ui-pkg
    cp dilshan-x-ui /tmp/dilshan-x-ui-pkg/
    cp -r web /tmp/dilshan-x-ui-pkg/
    cp -r bin /tmp/dilshan-x-ui-pkg/ 2>/dev/null
    
    cd /tmp
    tar -czf dilshan-x-ui.tar.gz -C /tmp/dilshan-x-ui-pkg .
    rm -rf dilshan-ui-src dilshan-x-ui-pkg
    
    echo -e "${GREEN}✓ Built successfully${NC}"
    return 0
}

download_release

# Install
echo -e "${CYAN}📂 Installing...${NC}"
mkdir -p $INSTALL_DIR
mkdir -p $CONFIG_DIR

cd $INSTALL_DIR
tar -xzf /tmp/dilshan-x-ui.tar.gz -C $INSTALL_DIR 2>/dev/null

# Make binary executable
chmod +x $INSTALL_DIR/dilshan-x-ui 2>/dev/null
chmod +x $INSTALL_DIR/x-ui 2>/dev/null
chmod +x $INSTALL_DIR/bin/* 2>/dev/null

rm -f /tmp/dilshan-x-ui.tar.gz

# Create systemd service
echo -e "${CYAN}⚙️  Creating systemd service...${NC}"
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Dilshan X-UI - Advanced Xray Management Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/x-ui
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Create management script
cat > /usr/bin/dilshan-x-ui << 'MGMT_EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE="dilshan-x-ui"

show_menu() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║        🛡️  Dilshan X-UI Manager          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e " ${GREEN}1.${NC} Start"
    echo -e " ${GREEN}2.${NC} Stop"
    echo -e " ${GREEN}3.${NC} Restart"
    echo -e " ${GREEN}4.${NC} Status"
    echo -e " ${GREEN}5.${NC} View Logs"
    echo -e " ${GREEN}6.${NC} Enable Auto-start"
    echo -e " ${GREEN}7.${NC} Disable Auto-start"
    echo -e " ${GREEN}8.${NC} Update"
    echo -e " ${GREEN}9.${NC} Uninstall"
    echo -e " ${GREEN}0.${NC} Exit"
    echo ""
}

case "$1" in
    start)   systemctl start $SERVICE && echo -e "${GREEN}✓ Started${NC}" ;;
    stop)    systemctl stop $SERVICE && echo -e "${YELLOW}⏹ Stopped${NC}" ;;
    restart) systemctl restart $SERVICE && echo -e "${GREEN}✓ Restarted${NC}" ;;
    status)  systemctl status $SERVICE ;;
    log)     journalctl -u $SERVICE -f ;;
    enable)  systemctl enable $SERVICE && echo -e "${GREEN}✓ Auto-start enabled${NC}" ;;
    update)
        echo -e "${CYAN}⬇️  Updating...${NC}"
        bash <(curl -Ls https://raw.githubusercontent.com/vishwa7502/dilshan-ui/main/install.sh)
        ;;
    uninstall)
        systemctl stop $SERVICE
        systemctl disable $SERVICE
        rm -f /etc/systemd/system/$SERVICE.service
        rm -rf /usr/local/dilshan-x-ui
        rm -f /usr/bin/dilshan-x-ui
        systemctl daemon-reload
        echo -e "${GREEN}✓ Uninstalled${NC}"
        ;;
    *)
        while true; do
            show_menu
            read -p "Select option: " choice
            case $choice in
                1) systemctl start $SERVICE && echo -e "${GREEN}✓ Started${NC}" ;;
                2) systemctl stop $SERVICE && echo -e "${YELLOW}⏹ Stopped${NC}" ;;
                3) systemctl restart $SERVICE && echo -e "${GREEN}✓ Restarted${NC}" ;;
                4) systemctl status $SERVICE ;;
                5) journalctl -u $SERVICE -f ;;
                6) systemctl enable $SERVICE && echo -e "${GREEN}✓ Auto-start enabled${NC}" ;;
                7) systemctl disable $SERVICE && echo -e "${YELLOW}⏹ Auto-start disabled${NC}" ;;
                8) bash <(curl -Ls https://raw.githubusercontent.com/vishwa7502/dilshan-ui/main/install.sh) ;;
                9) $0 uninstall; exit 0 ;;
                0) exit 0 ;;
                *) echo -e "${RED}Invalid option${NC}" ;;
            esac
            echo ""
        done
        ;;
esac
MGMT_EOF

chmod +x /usr/bin/dilshan-x-ui

# Reload systemd and start
systemctl daemon-reload
systemctl enable $SERVICE_NAME > /dev/null 2>&1
systemctl start $SERVICE_NAME

# Get panel port
PANEL_PORT=$(grep -oP '"port":\s*\K\d+' $CONFIG_DIR/config.json 2>/dev/null || echo "2053")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    ✅ Dilshan X-UI Installed!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Panel URL:${NC}   http://YOUR_IP:${PANEL_PORT}"
echo -e "  ${CYAN}Username:${NC}    admin"
echo -e "  ${CYAN}Password:${NC}    admin"
echo ""
echo -e "  ${YELLOW}⚠ Change default credentials after login!${NC}"
echo ""
echo -e "  ${CYAN}Management:${NC}  dilshan-x-ui"
echo -e "  ${CYAN}Start:${NC}       dilshan-x-ui start"
echo -e "  ${CYAN}Stop:${NC}        dilshan-x-ui stop"
echo -e "  ${CYAN}Restart:${NC}     dilshan-x-ui restart"
echo -e "  ${CYAN}Logs:${NC}        dilshan-x-ui log"
echo -e "  ${CYAN}Update:${NC}      dilshan-x-ui update"
echo ""
