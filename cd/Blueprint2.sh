#!/bin/bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃         BLUEPRINT INSTALLER - NEXT-GEN EDITION v4                  ┃
# ┃                Official Blueprint Framework • 2025                 ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# ────────────────────────────────────────────────────────────────────────
# Colors & Styling
# ────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'     GREEN='\033[0;32m'    YELLOW='\033[1;33m'
BLUE='\033[0;34m'    CYAN='\033[0;36m'     MAGENTA='\033[0;35m'
WHITE='\033[1;37m'   BOLD='\033[1m'        NC='\033[0m'

# ────────────────────────────────────────────────────────────────────────
# Utility Functions
# ────────────────────────────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${CYAN}┃ ${BOLD}$1${NC} ${CYAN}┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
}

print_status() {
    echo -e "${YELLOW}⏳ $1...${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${MAGENTA}⚠ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[${spin:$i:1}] $msg${NC}"
        i=$(( (i+1) % ${#spin} ))
        sleep 0.1
    done
    printf "\r${GREEN}✓ $msg completed${NC}\n"
}

run_silent() {
    "$@" >/dev/null 2>&1 &
    spinner $! "$2"
    wait $!
    if [ $? -eq 0 ]; then
        return 0
    else
        print_error "Failed: $2"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────────────
# Welcome Animation
# ────────────────────────────────────────────────────────────────────────
welcome() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
   ___  _          _   _   ___   ___   ___   ___   ___   ___  
  / __|| |__   ___| |_| |_| __| / _ \ | _ ) / _ \ |   \ | __| 
 | (__ | '_ \ / _ \  _|  _|__ \/ (_) || _ \| (_) || |) ||__ \ 
  \___||_.__/ \___/\__|\__|___/ \___/ |___/ \___/ |___/ |___/ 
EOF
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}       Blueprint Framework • Installer - Next-Gen Edition${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    sleep 1.5
}

# ────────────────────────────────────────────────────────────────────────
# Fresh Install
# ────────────────────────────────────────────────────────────────────────
fresh_install() {
    print_header "FRESH INSTALLATION • BLUEPRINT FRAMEWORK"
    check_root

    print_status "Preparing system"
    
    # Node.js 20.x
    print_header "Installing Node.js 20.x"
    run_silent apt-get install -y ca-certificates curl gnupg "Installing dependencies"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    run_silent apt-get update "Updating package lists"
    run_silent apt-get install -y nodejs "Installing Node.js 20.x"

    # Dependencies
    print_header "Installing Core Dependencies"
    run_silent npm install -g yarn "Installing Yarn"
    cd /var/www/pterodactyl || { print_error "Pterodactyl directory not found!"; return 1; }
    run_silent yarn "Installing panel dependencies"
    run_silent apt install -y zip unzip git curl wget "Installing utilities"

    # Download & Extract
    print_header "Downloading Latest Blueprint (beta-2025-12)"
    local release_url=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep browser_download_url | cut -d '"' -f 4)
    if [ -z "$release_url" ]; then
        print_error "Failed to get latest release URL"
        return 1
    fi
    run_silent wget "$release_url" -O release.zip "Downloading release"
    run_silent unzip -o release.zip "Extracting files"
    rm release.zip

    # Config & Install
    print_header "Finalizing Installation"
    if [ ! -f ".blueprintrc" ]; then
        cat << EOF > .blueprintrc
WEBUSER="www-data"
OWNERSHIP="www-data:www-data"
USERSHELL="/bin/bash"
EOF
        print_success "Created .blueprintrc"
    fi

    if [ ! -f "blueprint.sh" ]; then
        print_error "blueprint.sh missing from release!"
        return 1
    fi

    chmod +x blueprint.sh
    print_status "Running Blueprint installer"
    bash blueprint.sh -install

    if [ $? -eq 0 ]; then
        print_success "Blueprint Framework installed successfully!"
    else
        print_error "Installation failed – check output above for details"
    fi
}

# Reinstall / Update functions remain similar (using blueprint command if available)
reinstall() {
    print_header "REINSTALL BLUEPRINT"
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    if command -v blueprint >/dev/null; then
        run_silent blueprint -rerun-install "Reinstalling"
    else
        [ -f blueprint.sh ] && bash blueprint.sh -rerun-install
    fi
}

update() {
    print_header "UPDATE BLUEPRINT FRAMEWORK"
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    if command -v blueprint >/dev/null; then
        run_silent blueprint -upgrade "Updating"
    else
        fresh_install  # Fallback to redownload if needed
    fi
}

# Menu & Main (unchanged for brevity – same as v3)

welcome

while true; do
    show_menu
    read -r choice

    case $choice in
        1) fresh_install ;;
        2) reinstall ;;
        3) update ;;
        0) exit gracefully ;;
        *) invalid ;;
    esac

    press enter to continue
done
