#!/bin/bash
set -e

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃         BLUEPRINT INSTALLER - NEXT-GEN EDITION v4                  ┃
# ┃                Official Blueprint Framework • 2025                 ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# ────────────────────────────────────────────────────────────────────────
# Colors
# ────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

PANEL_DIR="/var/www/pterodactyl"

# ────────────────────────────────────────────────────────────────────────
# Utils
# ────────────────────────────────────────────────────────────────────────
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗ Run as root (sudo -i)${NC}"
        exit 1
    fi
}

run() {
    echo -e "${CYAN}⏳ $1...${NC}"
    shift
    if "$@"; then
        echo -e "${GREEN}✓ Done${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        exit 1
    fi
}

header() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD} $1 ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

pause() {
    read -rp "Press ENTER to continue..."
}

# ────────────────────────────────────────────────────────────────────────
# Welcome
# ────────────────────────────────────────────────────────────────────────
welcome() {
clear
cat << "EOF"
   ___  _          _   _   ___   ___   ___   ___
  / __|| |__   ___| |_| |_| __| / _ \ | _ )
 | (__ | '_ \ / _ \  _|  _|__ \/ (_) || _ \
  \___||_.__/ \___/\__|\__|___/ \___/ |___/
EOF
echo -e "${CYAN}Blueprint Framework • Installer${NC}\n"
sleep 1
}

# ────────────────────────────────────────────────────────────────────────
# Fresh Install
# ────────────────────────────────────────────────────────────────────────
fresh_install() {
    check_root
    header "FRESH INSTALL – BLUEPRINT"

    run "Installing dependencies" apt update
    run "Installing packages" apt install -y curl git unzip zip ca-certificates gnupg

    # Node.js 20
    if ! command -v node >/dev/null; then
        run "Adding NodeSource repo" bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
        run "Installing Node.js 20" apt install -y nodejs
    fi

    run "Installing Yarn" npm install -g yarn

    if [ ! -d "$PANEL_DIR" ]; then
        echo -e "${RED}✗ Pterodactyl panel not found at $PANEL_DIR${NC}"
        exit 1
    fi

    cd "$PANEL_DIR"

    run "Installing panel dependencies" yarn install --production

    header "Downloading Blueprint"

    RELEASE_URL=$(curl -fsSL https://api.github.com/repos/BlueprintFramework/framework/releases/latest \
        | grep browser_download_url \
        | head -n1 \
        | cut -d '"' -f4)

    if [ -z "$RELEASE_URL" ]; then
        echo -e "${RED}✗ Failed to fetch release${NC}"
        exit 1
    fi

    run "Downloading Blueprint" wget -O blueprint.zip "$RELEASE_URL"
    run "Extracting Blueprint" unzip -o blueprint.zip
    rm blueprint.zip

    if [ ! -f blueprint.sh ]; then
        echo -e "${RED}✗ blueprint.sh missing${NC}"
        exit 1
    fi

    chmod +x blueprint.sh
    run "Running Blueprint installer" bash blueprint.sh -install

    ln -sf "$PANEL_DIR/blueprint.sh" /usr/local/bin/blueprint

    echo -e "${GREEN}\n✓ Blueprint installed successfully${NC}"
}

# ────────────────────────────────────────────────────────────────────────
# Reinstall
# ────────────────────────────────────────────────────────────────────────
reinstall() {
    cd "$PANEL_DIR"
    if command -v blueprint >/dev/null; then
        blueprint -rerun-install
    else
        bash blueprint.sh -rerun-install
    fi
}

# ────────────────────────────────────────────────────────────────────────
# Update
# ────────────────────────────────────────────────────────────────────────
update() {
    cd "$PANEL_DIR"
    if command -v blueprint >/dev/null; then
        blueprint -upgrade
    else
        fresh_install
    fi
}

# ────────────────────────────────────────────────────────────────────────
# Menu
# ────────────────────────────────────────────────────────────────────────
show_menu() {
    echo "1) Fresh Install"
    echo "2) Reinstall"
    echo "3) Update"
    echo "0) Exit"
    echo
    read -rp "Select: " choice
}

# ────────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────────
welcome

while true; do
    show_menu
    case "$choice" in
        1) fresh_install ;;
        2) reinstall ;;
        3) update ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    pause
done
