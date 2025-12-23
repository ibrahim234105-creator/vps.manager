#!/bin/bash
set -e

# Colors for output (Nord-inspired theme with full bright colors for better visibility)
RED='\033[0;91m'          # Bright Red
GREEN='\033[0;92m'        # Bright Green
YELLOW='\033[1;93m'       # Bright Yellow
BLUE='\033[0;94m'         # Bright Blue
PURPLE='\033[0;95m'       # Bright Purple
CYAN='\033[0;96m'         # Bright Cyan
WHITE='\033[1;97m'        # Bright White
GRAY='\033[0;90m'         # Bright Gray
BOLD='\033[1m'
NC='\033[0m'              # No Color

# Backgrounds (subtle but visible accents)
BG_BLUE='\033[48;5;17m'   # Dark blue background
BG_PURPLE='\033[48;5;53m' # Dark purple background

# Function to print section headers
print_header() {
    echo -e "\n${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BG_PURPLE}${WHITE}${BOLD}  $1  ${NC}"
    echo -e "${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}\n"
}

# Status messages with full bright colors
print_status() {
    echo -e "${YELLOW}${BOLD}⏳ $1...${NC}"
}
print_success() {
    echo -e "${GREEN}${BOLD}✅ $1${NC}"
}
print_error() {
    echo -e "${RED}${BOLD}❌ $1${NC}"
}
print_info() {
    echo -e "${CYAN}${BOLD}ℹ️  $1${NC}"
}

# Check command success
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
        return 0
    else
        print_error "$2"
        return 1
    fi
}

# Welcome banner
clear
echo -e "${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BG_PURPLE}${WHITE}${BOLD}        PTERODACTYL WINGS SETUP SCRIPT         ${NC}"
echo -e "${BG_PURPLE}${WHITE}${BOLD}               by MahimOp                     ${NC}"
echo -e "${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}\n"

print_info "Script created and maintained by MahimOp"
print_info "Discord: https://discord.gg/your-discord-invite-link"  # <-- Replace with your actual link

# Root check
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_header "STARTING WINGS INSTALLATION PROCESS"

# 1. Docker install
print_header "INSTALLING DOCKER"
print_status "Installing Docker"
curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1
check_success "Docker installed successfully" "Failed to install Docker"

print_status "Enabling and starting Docker service"
sudo systemctl enable --now docker > /dev/null 2>&1
check_success "Docker service started and enabled" "Failed to start Docker service"

# 2. Update GRUB
print_header "UPDATING SYSTEM CONFIGURATION"
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    print_status "Updating GRUB configuration"
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' $GRUB_FILE
    sudo update-grub > /dev/null 2>&1
    check_success "GRUB configuration updated" "Failed to update GRUB"
else
    print_info "GRUB configuration file not found, skipping"
fi

# 3. Wings install
print_header "INSTALLING WINGS"
print_status "Creating Pterodactyl directory"
sudo mkdir -p /etc/pterodactyl
check_success "Directory created" "Failed to create directory"

print_status "Detecting system architecture"
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    ARCH="amd64"
    print_success "Detected AMD64 architecture"
elif [ "$ARCH" == "aarch64" ]; then
    ARCH="arm64"
    print_success "Detected ARM64 architecture"
else
    print_error "Unsupported architecture: $ARCH"
    exit 1
fi

print_status "Downloading Wings"
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" > /dev/null 2>&1
check_success "Wings downloaded" "Failed to download Wings"

print_status "Setting executable permissions"
sudo chmod u+x /usr/local/bin/wings
check_success "Permissions set" "Failed to set permissions"

# 4. Wings service
print_header "CONFIGURING WINGS SERVICE"
print_status "Creating systemd service file"
sudo tee /etc/systemd/system/wings.service > /dev/null <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
check_success "Service file created" "Failed to create service file"

print_status "Reloading systemd daemon"
sudo systemctl daemon-reload > /dev/null 2>&1
check_success "Systemd daemon reloaded" "Failed to reload systemd"

print_status "Enabling Wings service"
sudo systemctl enable wings > /dev/null 2>&1
check_success "Wings service enabled" "Failed to enable Wings service"

# 5. SSL Certificate
print_header "GENERATING SSL CERTIFICATE"
print_status "Creating certificate directory"
sudo mkdir -p /etc/certs/wing
cd /etc/certs/wing

print_status "Generating self-signed SSL certificate"
sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
  -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
  -keyout privkey.pem -out fullchain.pem > /dev/null 2>&1
check_success "SSL certificate generated" "Failed to generate SSL certificate"

# 6. wing helper command
print_header "CREATING WING HELPER COMMAND"
print_status "Installing helper script"
sudo tee /usr/local/bin/wing > /dev/null <<'EOF'
#!/bin/bash
echo -e "\033[0;95m╔══════════════════════════════════════════╗\033[0m"
echo -e "\033[0;95m║          Wings Helper Command            ║\033[0m"
echo -e "\033[0;95m╚══════════════════════════════════════════╝\033[0m"
echo
echo -e "\033[0;96mTo start Wings:\033[0m          \033[0;92msudo systemctl start wings\033[0m"
echo -e "\033[0;96mCheck status:\033[0m           \033[0;92msudo systemctl status wings\033[0m"
echo -e "\033[0;96mView live logs:\033[0m         \033[0;92msudo journalctl -u wings -f\033[0m"
echo
echo -e "\033[1;93m⚠️  Ensure port 8080 → 443 is mapped in your node config!\033[0m"
echo
echo -e "\033[0;94mDiscord Support: https://discord.gg/your-discord-invite-link\033[0m"
echo
EOF
sudo chmod +x /usr/local/bin/wing
check_success "Helper command 'wing' created" "Failed to create helper"

# Installation complete
print_header "INSTALLATION COMPLETED SUCCESSFULLY"
echo -e "${GREEN}${BOLD}🎉 Pterodactyl Wings is now fully installed!${NC}\n"
echo -e "${WHITE}${BOLD}📋 Next Steps:${NC}"
echo -e " ${CYAN}•${NC} Configure Wings using the auto-config option below or manually"
echo -e " ${CYAN}•${NC} Start the service: ${GREEN}sudo systemctl start wings${NC}"
echo -e " ${CYAN}•${NC} Quick help anytime: ${GREEN}wing${NC}\n"

# 7. Auto-configure
echo -e "${PURPLE}${BOLD}🔧 OPTIONAL: AUTO-CONFIGURE WINGS${NC}"
read -p "$(echo -e "${YELLOW}Would you like to auto-configure Wings now? (y/N): ${NC}")" AUTO_CONFIG
if [[ "$AUTO_CONFIG" =~ ^[Yy]$ ]]; then
    print_header "AUTO-CONFIGURING WINGS"
    echo -e "${YELLOW}Please enter the details from your Pterodactyl Panel → Nodes → Configuration:${NC}\n"
    read -p "$(echo -e "${CYAN}Node UUID: ${NC}")" UUID
    read -p "$(echo -e "${CYAN}Token ID: ${NC}")" TOKEN_ID
    read -p "$(echo -e "${CYAN}Token: ${NC}")" TOKEN
    read -p "$(echo -e "${CYAN}Panel URL (e.g., https://panel.example.com): ${NC}")" REMOTE

    print_status "Writing configuration file"
    sudo mkdir -p /etc/pterodactyl
    sudo tee /etc/pterodactyl/config.yml > /dev/null <<CFG
debug: false
uuid: ${UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: '${REMOTE}'
CFG
    check_success "Configuration saved to /etc/pterodactyl/config.yml" "Failed to save configuration"

    print_status "Starting Wings service"
    sudo systemctl start wings
    check_success "Wings service started successfully" "Failed to start Wings"

    echo -e "\n${GREEN}${BOLD}✅ Auto-configuration complete!${NC}"
    echo -e "${YELLOW}Check status:${NC} ${GREEN}systemctl status wings${NC}"
    echo -e "${YELLOW}Follow logs:${NC} ${GREEN}journalctl -u wings -f${NC}\n"
else
    echo -e "\n${YELLOW}⚠️ Auto-configuration skipped.${NC}"
    echo -e "${YELLOW}Manual steps:${NC}"
    echo -e " 1. Create/edit ${GREEN}/etc/pterodactyl/config.yml${NC} with your node details"
    echo -e " 2. Start Wings: ${GREEN}sudo systemctl start wings${NC}\n"
    echo -e "Run ${GREEN}wing${NC} anytime for quick commands.\n"
fi

# Final footer
echo -e "${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BG_PURPLE}${WHITE}${BOLD}           Thank you for using this script!           ${NC}"
echo -e "${CYAN}${BOLD}       Author: MahimOp                                ${NC}"
echo -e "${CYAN}${BOLD}       Discord: https://discord.gg/your-discord-invite-link       ${NC}"
echo -e "${BG_BLUE}${WHITE}${BOLD}══════════════════════════════════════════════════════════${NC}\n"
