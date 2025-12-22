#!/bin/bash

# =============================================================================
# Blueprint Framework Installer for Pterodactyl Panel
# Fully Remastered, Redesigned & Colorful – December 2025
# =============================================================================

set -euo pipefail

# ----------------------------- Color Definitions -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# ----------------------------- Logging Functions -----------------------------
banner() {
    echo -e "${PURPLE}${BOLD}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '='
    echo "                           $1"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '='
    echo -e "${NC}"
}

log() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $*"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $*" >&2; }
step() { echo -e "${CYAN}${BOLD}>>>${NC} ${WHITE}$*${NC}"; }

# ----------------------------- Configuration ---------------------------------
PTERODACTYL_DIRECTORY="/var/www/pterodactyl"
BLUEPRINT_REPO="BlueprintFramework/framework"
NODE_VERSION="20"

# ----------------------------- Welcome Banner --------------------------------
clear
banner "Blueprint Framework Installer"
echo

# ----------------------------- Root & Directory Check ------------------------
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)."
    exit 1
fi

if [[ ! -d "$PTERODACTYL_DIRECTORY" ]]; then
    error "Pterodactyl directory not found at: $PTERODACTYL_DIRECTORY"
    error "Ensure Pterodactyl Panel is installed correctly before proceeding."
    exit 1
fi

cd "$PTERODACTYL_DIRECTORY"

# ----------------------------- Install System Dependencies -------------------
step "Updating package index and installing system dependencies"
apt update --quiet > /dev/null
apt install -y ca-certificates curl wget unzip git gnupg zip > /dev/null 2>&1
log "System dependencies installed successfully"

# ----------------------------- Install Node.js 20 -----------------------------
step "Configuring NodeSource repository for Node.js $NODE_VERSION"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg > /dev/null

cat > /etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main
EOF

apt update --quiet > /dev/null
apt install -y nodejs > /dev/null 2>&1

node_ver=$(node -v)
npm_ver=$(npm -v)
log "Node.js $node_ver and npm $npm_ver installed"

# Install Yarn globally if not present
if ! command -v yarn &> /dev/null; then
    step "Installing Yarn package manager globally"
    npm i -g yarn > /dev/null 2>&1
    log "Yarn installed successfully"
else
    info "Yarn is already installed"
fi

# ----------------------------- Download Latest Release -----------------------
step "Retrieving latest Blueprint Framework release"
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${BLUEPRINT_REPO}/releases/latest" \
    | grep "browser_download_url.*\.zip" \
    | cut -d '"' -f 4 \
    | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
    error "Failed to retrieve download URL for latest release"
    error "Check your internet connection or the repository status"
    exit 1
fi

info "Download URL: $DOWNLOAD_URL"
wget --quiet --show-progress -O release.zip "$DOWNLOAD_URL"
log "Latest release downloaded"

step "Extracting Blueprint Framework files"
unzip -o release.zip > /dev/null
rm release.zip
log "Files extracted and temporary archive removed"

# ----------------------------- Install Node Dependencies ---------------------
step "Installing project dependencies with Yarn"
yarn install --frozen-lockfile > /dev/null 2>&1
log "All dependencies installed"

# ----------------------------- Create Configuration ---------------------------
step "Generating .blueprintrc configuration file"
cat > .blueprintrc << 'EOF'
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF
log ".blueprintrc created with standard web server settings"

# Ensure blueprint.sh is executable
if [[ -f "blueprint.sh" ]]; then
    chmod +x blueprint.sh
    log "blueprint.sh set as executable"
else
    error "blueprint.sh not found after extraction"
    exit 1
fi

# ----------------------------- Run Blueprint Installer -----------------------
banner "Executing Blueprint Framework Installer"
echo
bash ./blueprint.sh

# ----------------------------- Completion Message ----------------------------
clear
banner "Installation Completed Successfully"
echo
log "Blueprint Framework has been fully installed and configured"
warn "Recommended post-installation steps:"
echo "   • Clear PHP cache: php artisan view:clear && php artisan config:cache"
echo "   • Clear browser cache or use incognito mode"
echo "   • Check the panel for any Blueprint setup prompts"
echo
info "You can now enjoy the enhanced Pterodactyl experience with Blueprint!"

exit 0
