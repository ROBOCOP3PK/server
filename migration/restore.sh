#!/bin/bash
# Restaurar servidor desde backup
set -e

BACKUP_DIR="/home/david/migration-backup"

echo "=== RESTAURACION DEL SERVIDOR ==="

# Verificar backup
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: No existe $BACKUP_DIR"
    echo "Ejecuta: tar -xzvf migration-backup-*.tar.gz"
    exit 1
fi

# 1. Sistema
echo "[1/12] Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Nginx
echo "[2/12] Nginx..."
sudo apt install nginx -y
sudo systemctl enable nginx

# 3. PHP 8.3
echo "[3/12] PHP 8.3..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.3-fpm php8.3-cli php8.3-common php8.3-mysql \
    php8.3-xml php8.3-curl php8.3-gd php8.3-mbstring php8.3-zip \
    php8.3-bcmath php8.3-intl php8.3-sqlite3 -y

# 4. Composer
echo "[4/12] Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# 5. Node.js 20
echo "[5/12] Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y

# 6. MySQL (si hay backups)
if [ -n "$(ls -A $BACKUP_DIR/mysql/*.sql 2>/dev/null)" ]; then
    echo "[6/12] MySQL..."
    sudo apt install mysql-server -y
    sudo systemctl enable mysql
else
    echo "[6/12] MySQL no necesario"
fi

# 7. Herramientas
echo "[7/12] Herramientas..."
sudo apt install git ufw fail2ban lm-sensors unzip -y

# Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
echo "y" | sudo ufw enable

# Sensores
sudo sensors-detect --auto

# No suspender al cerrar tapa
sudo sed -i 's/#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# 8. Apps Laravel
echo "[8/12] Apps Laravel..."
sudo mkdir -p /var/www

for app_dir in $BACKUP_DIR/apps/*/; do
    app_name=$(basename "$app_dir")
    echo "  - $app_name"

    # Clonar desde git
    if [ -f "$app_dir/git-remote.txt" ]; then
        git_url=$(cat "$app_dir/git-remote.txt")
        sudo git clone "$git_url" "/var/www/$app_name" 2>/dev/null || true
    fi

    if [ -d "/var/www/$app_name" ]; then
        sudo chown -R david:david "/var/www/$app_name"
        cd "/var/www/$app_name"

        # Restaurar .env
        [ -f "$app_dir/.env" ] && cp "$app_dir/.env" .env

        # Dependencias
        composer install --optimize-autoloader --no-dev 2>/dev/null || true
        npm install 2>/dev/null || true
        npm run build 2>/dev/null || true

        # SQLite
        if [ -f "$app_dir/database.sqlite" ]; then
            mkdir -p database
            cp "$app_dir/database.sqlite" database/
        fi

        # Permisos
        sudo chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
        sudo chmod -R 775 storage bootstrap/cache 2>/dev/null || true

        # Cache
        php artisan config:cache 2>/dev/null || true
        php artisan route:cache 2>/dev/null || true
    fi
done

# 9. Nginx configs
echo "[9/12] Nginx configs..."
for conf in $BACKUP_DIR/nginx/*; do
    [ -f "$conf" ] || continue
    conf_name=$(basename "$conf")
    sudo cp "$conf" "/etc/nginx/sites-available/$conf_name"
    sudo ln -sf "/etc/nginx/sites-available/$conf_name" "/etc/nginx/sites-enabled/"
done
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# 10. Cloudflare Tunnel
echo "[10/12] Cloudflare Tunnel..."
curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
rm /tmp/cloudflared.deb

sudo mkdir -p /etc/cloudflared
mkdir -p ~/.cloudflared

[ -f "$BACKUP_DIR/cloudflared/config.yml" ] && sudo cp "$BACKUP_DIR/cloudflared/config.yml" /etc/cloudflared/
[ -f "$BACKUP_DIR/cloudflared/cert.pem" ] && cp "$BACKUP_DIR/cloudflared/cert.pem" ~/.cloudflared/
for json in $BACKUP_DIR/cloudflared/*.json; do
    [ -f "$json" ] && sudo cp "$json" /etc/cloudflared/
done

sudo cloudflared service install 2>/dev/null || true
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# 11. FileBrowser
echo "[11/12] FileBrowser..."
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
mkdir -p ~/archivos

# Restaurar DB de FileBrowser si existe
if [ -f "$BACKUP_DIR/home/.filebrowser.db" ]; then
    cp "$BACKUP_DIR/home/.filebrowser.db" ~/
else
    # Crear nueva config
    filebrowser config init --database ~/.filebrowser.db
    filebrowser config set --address 0.0.0.0 --port 8080 --root ~/archivos --database ~/.filebrowser.db
    echo "NOTA: Crear usuario FileBrowser con:"
    echo "  filebrowser users add admin TU_PASSWORD --database ~/.filebrowser.db"
fi

# Servicio FileBrowser
sudo tee /etc/systemd/system/filebrowser.service > /dev/null << 'EOF'
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
User=david
ExecStart=/usr/local/bin/filebrowser --database /home/david/.filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl start filebrowser

# 12. Restaurar home
echo "[12/12] Home..."
[ -f "$BACKUP_DIR/home/backup-db.sh" ] && cp "$BACKUP_DIR/home/backup-db.sh" ~/ && chmod +x ~/backup-db.sh
[ -f "$BACKUP_DIR/home/crontab.txt" ] && crontab "$BACKUP_DIR/home/crontab.txt"

# MySQL (si hay backups)
if [ -n "$(ls -A $BACKUP_DIR/mysql/*.sql 2>/dev/null)" ]; then
    echo "Restaurando MySQL..."
    for sql in $BACKUP_DIR/mysql/*.sql; do
        [ -f "$sql" ] || continue
        db=$(basename "$sql" .sql)
        echo "  - $db"
        sudo mysql -e "CREATE DATABASE IF NOT EXISTS $db;"
        sudo mysql "$db" < "$sql"
    done
fi

# Resultado
echo ""
echo "=== COMPLETADO ==="
echo ""
echo "Servicios:"
echo "  Nginx:       $(systemctl is-active nginx)"
echo "  PHP-FPM:     $(systemctl is-active php8.3-fpm)"
echo "  cloudflared: $(systemctl is-active cloudflared)"
echo "  FileBrowser: $(systemctl is-active filebrowser)"
echo "  Fail2ban:    $(systemctl is-active fail2ban)"
echo ""
echo "Verificar:"
echo "  - https://finanzas.davidhub.space"
echo "  - https://archivos.davidhub.space"
echo ""
echo "Si FileBrowser es nuevo, crear usuario:"
echo "  filebrowser users add admin TU_PASSWORD --database ~/.filebrowser.db"
