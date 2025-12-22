#!/bin/bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃         BLUEPRINT INSTALLER - NEXT-GEN EDITION v3                  ┃
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
# Welcome Animation (Next-Gen Style)
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
# Fresh Install (Full Setup)
# ────────────────────────────────────────────────────────────────────────
fresh_install() {
    print_header "FRESH INSTALLATION • BLUEPRINT FRAMEWORK"
    check_root

    print_status "Preparing system for Blueprint installation"
    
    # Step 1: Node.js 20.x
    print_header "Installing Node.js 20.x"
    run_silent apt-get install -y ca-certificates curl gnupg "Installing dependencies"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    run_silent apt-get update "Updating package lists"
    run_silent apt-get install -y nodejs "Installing Node.js 20.x"

    # Step 2: Yarn & Dependencies
    print_header "Installing Core Dependencies"
    run_silent npm install -g yarn "Installing Yarn globally"
    cd /var/www/pterodactyl || { print_error "Pterodactyl panel directory not found (/var/www/pterodactyl)"; return 1; }
    run_silent yarn "Installing panel dependencies"
    run_silent apt install -y zip unzip git curl wget "Installing utilities"

    # Step 3: Download & Extract Blueprint Release
    print_header "Downloading Blueprint Framework"
    local release_url=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep browser_download_url | cut -d '"' -f 4)
    if [ -z "$release_url" ]; then
        print_error "Could not retrieve latest release URL"
        return 1
    fi
    run_silent wget "$release_url" -O release.zip "Downloading latest release"
    run_silent unzip -o release.zip "Extracting files"
    rm release.zip  # Clean up

    print_success "Blueprint Framework installed successfully!"
    print_status "You can now run 'blueprint' commands in the panel directory"
}

# ────────────────────────────────────────────────────────────────────────
# Reinstall (Rerun Only)
# ────────────────────────────────────────────────────────────────────────
reinstall() {
    print_header "REINSTALL BLUEPRINT (RERUN ONLY)"
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    run_silent blueprint -rerun-install "Re-running Blueprint installer"
    print_success "Reinstallation completed!"
}

# ────────────────────────────────────────────────────────────────────────
# Update
# ────────────────────────────────────────────────────────────────────────
update() {
    print_header "UPDATE BLUEPRINT FRAMEWORK"
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    run_silent blueprint -upgrade "Applying latest updates"
    print_success "Update completed successfully!"
}

# ────────────────────────────────────────────────────────────────────────
# Main Menu (Sleek & Modern)
# ────────────────────────────────────────────────────────────────────────
show_menu() {
    clear
    print_header "BLUEPRINT INSTALLER - NEXT-GEN"
    echo -e "${WHITE}┌───────────────────────────────────────────────────────┐${NC}"
    echo -e "│ ${CYAN}${BOLD}Official Blueprint Framework for Pterodactyl${NC}        │"
    echo -e "├───────────────────────────────────────────────────────┤${NC}"
    echo -e "│ ${GREEN}1${NC}  Fresh Install (Download & setup Blueprint)        │"
    echo -e "│ ${GREEN}2${NC}  Reinstall (Rerun Blueprint installer)             │"
    echo -e "│ ${GREEN}3${NC}  Update Blueprint Framework                        │"
    echo -e "│ ${RED}0${NC}  Exit                                              │"
    echo -e "└───────────────────────────────────────────────────────┘${NC}\n"
    echo -e "${YELLOW}➤ Enter your choice (0-3): ${NC}"
}

# ────────────────────────────────────────────────────────────────────────
# Main Program
# ────────────────────────────────────────────────────────────────────────
welcome

while true; do
    show_menu
    read -r choice

    case $choice in
        1) fresh_install ;;
        2) reinstall ;;
        3) update ;;
        0)
            clear
            echo -e "${GREEN}${BOLD}Thank you for using Blueprint Installer Next-Gen Edition!${NC}"
            echo -e "${CYAN}Pterodactyl modding made powerful and simple${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sleep 2
            exit 0
            ;;
        *) print_error "Invalid choice! Please select 0-3" ; sleep 1 ;;
    esac

    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -n 1 -s
done
