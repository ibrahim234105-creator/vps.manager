#!/bin/bash
clear
echo -e "\e[1;36mPterodactyl Panel Minimal Installer\e[0m"
echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m\n"

read -p $'\e[1;34mEnter your domain (e.g., panel.example.com): \e[0m' DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo -e "\e[1;31mError: Domain is required!\e[0m"
    exit 1
fi

# Fixed credentials (change DB_PASS if desired - use a strong password!)
DB_NAME="panel"
DB_USER="pterodactyl"
DB_PASS="youPassword"
ADMIN_PASS="youPassword"  # Same as DB for simplicity - customize if needed
PHP_VERSION="8.3"

# --- Dependencies ---
echo -e "\n\e[1;32mUpdating system and installing dependencies...\e[0m"
apt update -qq && apt upgrade -y -qq
apt install -y curl apt-transport-https ca-certificates gnupg lsb-release unzip git tar sudo software-properties-common -qq

# Detect OS
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

if [[ "$OS" == "ubuntu" ]]; then
    echo "✅ Detected Ubuntu. Adding Ondřej PHP PPA..."
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
    echo "✅ Detected Debian. Adding SURY PHP repo..."
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $CODENAME main" > /etc/apt/sources.list.d/sury-php.list
else
    echo -e "\e[1;31mUnsupported OS: $OS\e[0m"
    exit 1
fi

# Redis repo
echo "Adding Redis repository..."
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $CODENAME main" > /etc/apt/sources.list.d/redis.list

apt update -qq

# --- Install packages ---
echo "Installing PHP $PHP_VERSION, Nginx, MariaDB, Redis & tools..."
apt install -y \
    php${PHP_VERSION} php${PHP_VERSION}-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} \
    mariadb-server nginx redis cron -qq

# --- Composer ---
echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# --- Download Panel ---
echo "Downloading latest Pterodactyl Panel..."
mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz && rm panel.tar.gz
chmod -R 755 storage/* bootstrap/cache

# --- Database Setup ---
echo "Creating database and user..."
mariadb << EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

# --- .env Setup ---
echo "Configuring .env..."
if [ ! -f ".env.example" ]; then
    curl -Lo .env.example https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example
fi
cp .env.example .env
sed -i \
    -e "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" \
    -e "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" \
    -e "s|DB_PORT=.*|DB_PORT=3306|g" \
    -e "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" \
    -e "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" \
    -e "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" \
    -e "s|APP_ENV=.*|APP_ENV=production|g" \
    -e "s|APP_DEBUG=.*|APP_DEBUG=false|g" \
    .env

if ! grep -q "^APP_ENVIRONMENT_ONLY=" .env; then
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
fi

# --- Composer dependencies & migrations ---
echo "Installing dependencies & running migrations..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --quiet
php artisan key:generate --force
php artisan migrate --seed --force

# --- Automatically create admin user (customize if needed) ---
echo "Creating initial admin user..."
php artisan p:user:make \
    --email=admin@${DOMAIN} \
    --username=admin \
    --name-first=Admin \
    --name-last=User \
    --password=${ADMIN_PASS} \
    --admin=1

# --- Permissions & Cron ---
chown -R www-data:www-data /var/www/pterodactyl
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# --- Self-signed SSL ---
echo "Generating self-signed SSL certificate..."
mkdir -p /etc/ssl/pterodactyl
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout /etc/ssl/pterodactyl/privkey.pem \
    -out /etc/ssl/pterodactyl/fullchain.pem \
    -subj "/CN=${DOMAIN}" > /dev/null 2>&1

# --- Nginx Config ---
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/pterodactyl.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    ssl_certificate /etc/ssl/pterodactyl/fullchain.pem;
    ssl_certificate_key /etc/ssl/pterodactyl/privkey.pem;

    client_max_body_size 100M;
    client_body_timeout 120s;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# --- Queue Worker ---
echo "Setting up queue worker..."
cat > /etc/systemd/system/pteroq.service << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
RestartSec=5
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server pteroq.service

# --- Final Output ---
clear
echo -e "\n\e[1;32m✔ Pterodactyl Panel Setup Complete!\e[0m"
echo -ne "\e[1;34mFinalizing installation"
for i in {1..5}; do echo -n "."; sleep 0.5; done
echo -e "\n"
echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[1;36m ✅ Installation Completed Successfully! \e[0m"
echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[1;32m 🌐 Panel URL: \e[1;37mhttps://${DOMAIN}\e[0m"
echo -e "\e[1;32m 📂 Panel Directory: \e[1;37m/var/www/pterodactyl\e[0m\n"
echo -e "\e[1;32m 🚀 Admin Login (SAVE THESE!)\e[0m"
echo -e "   \e[1;37mEmail: admin@${DOMAIN}\e[0m"
echo -e "   \e[1;37mUsername: admin\e[0m"
echo -e "   \e[1;37mPassword: youPassword\e[0m\n"
echo -e "\e[1;32m 🔑 Database Credentials\e[0m"
echo -e "   \e[1;37mDatabase: ${DB_NAME}\e[0m"
echo -e "   \e[1;37mUser: ${DB_USER}\e[0m"
echo -e "   \e[1;37mPassword: ${DB_PASS}\e[0m\n"
echo -e "\e[1;33mTip: For production, replace self-signed cert with Let's Encrypt:\e[0m"
echo -e "   sudo apt install certbot python3-certbot-nginx && sudo certbot --nginx -d ${DOMAIN}\n"
echo -e "\e[1;35m 🎉 Enjoy your Pterodactyl Panel! 🦅\e[0m"
