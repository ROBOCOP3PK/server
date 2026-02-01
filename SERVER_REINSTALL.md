# Server Reinstall - Guia de Instalacion desde Cero

> Pasos para reinstalar el servidor HP G42 con Ubuntu Server 22.04 LTS.

---

## 1. Crear USB Booteable

**Requisitos:** USB 4GB+, ISO Ubuntu Server 22.04 LTS

**Windows (Rufus):**
1. Descargar Rufus: https://rufus.ie
2. Configurar:
   - Dispositivo: Tu USB
   - ISO: `ubuntu-22.04-live-server-amd64.iso`
   - Esquema particion: **MBR** (HP G42 es BIOS Legacy)
   - Sistema destino: **BIOS**
3. Click EMPEZAR

**Linux:**
```bash
sudo dd if=ubuntu-22.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
```

---

## 2. Instalar Ubuntu Server

1. Insertar USB, encender PC
2. **HP G42:** Presionar `Esc` repetidamente → `F9` (Boot Menu) → Seleccionar USB
3. Seleccionar: `Ubuntu Server with the HWE kernel`

**Opciones de instalacion:**
- Idioma: English
- Teclado: Spanish (Latin American)
- Tipo: Ubuntu Server (NO minimized)
- Red: Anotar IP asignada
- Proxy: Vacio
- Storage: Use entire disk, **NO LVM**
- Perfil: usuario `david`, hostname `homeserver`
- Ubuntu Pro: Skip
- SSH: **Marcar** Install OpenSSH server
- Snaps: NO seleccionar nada

4. Esperar instalacion → Reboot → Retirar USB

**Primer inicio:**
```bash
sudo apt update && sudo apt upgrade -y
ip a  # Anotar IP
```

---

## 3. Configuracion Inicial

```bash
# Zona horaria
sudo timedatectl set-timezone America/Bogota

# No suspender al cerrar tapa
sudo nano /etc/systemd/logind.conf
```
Descomentar:
```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```
```bash
sudo systemctl restart systemd-logind
```

---

## 4. Instalar Stack

### 4.1 Nginx
```bash
sudo apt install nginx -y
sudo systemctl enable nginx
```

### 4.2 PHP 8.3
```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.3-fpm php8.3-cli php8.3-common php8.3-mysql \
    php8.3-xml php8.3-curl php8.3-gd php8.3-mbstring php8.3-zip \
    php8.3-bcmath php8.3-intl php8.3-sqlite3 -y
```

### 4.3 Composer
```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### 4.4 Node.js 20
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y
```

### 4.5 Git
```bash
sudo apt install git -y
git config --global user.email "tu-email@ejemplo.com"
git config --global user.name "Tu Nombre"
git config --global credential.helper store
```

### 4.6 Seguridad
```bash
# Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban

# Sensores temperatura
sudo apt install lm-sensors -y
sudo sensors-detect  # Enter a todo
```

### 4.7 Docker (Opcional - para n8n y otros servicios)
```bash
# Instalar dependencias
sudo apt install -y ca-certificates curl gnupg lsb-release

# Agregar repositorio de Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Permitir usar Docker sin sudo
sudo usermod -aG docker $USER

# Cerrar sesión y volver a entrar, luego verificar:
docker --version
docker run hello-world
```

> Docker permite correr aplicaciones en contenedores aislados. Útil para n8n, bases de datos de prueba, etc. No afecta las apps Laravel existentes.

---

## 5. Cloudflare Tunnel

### 5.1 Instalar cloudflared
```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
rm cloudflared.deb
```

### 5.2 Autenticar
```bash
cloudflared tunnel login
# Abre URL → Seleccionar dominio davidhub.space → Authorize
```

### 5.3 Crear tunel
```bash
cloudflared tunnel create finanzas
# Guardar el ID que muestra

cloudflared tunnel route dns finanzas finanzas.davidhub.space
cloudflared tunnel route dns finanzas tienda.davidhub.space
cloudflared tunnel route dns finanzas domicilios.davidhub.space
cloudflared tunnel route dns finanzas archivos.davidhub.space
```

### 5.4 Configurar
```bash
nano ~/.cloudflared/config.yml
```
```yaml
tunnel: TU_TUNNEL_ID
credentials-file: /home/david/.cloudflared/TU_TUNNEL_ID.json

ingress:
  - hostname: finanzas.davidhub.space
    service: http://localhost:80
  - hostname: tienda.davidhub.space
    service: http://localhost:80
  - hostname: domicilios.davidhub.space
    service: http://localhost:80
  - hostname: archivos.davidhub.space
    service: http://localhost:8080
  - service: http_status:404
```

### 5.5 Instalar como servicio
```bash
sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/
sudo cp ~/.cloudflared/*.json /etc/cloudflared/

# Actualizar ruta en config
sudo nano /etc/cloudflared/config.yml
# Cambiar credentials-file a: /etc/cloudflared/TU_TUNNEL_ID.json

sudo cloudflared service install
sudo systemctl status cloudflared
```

---

## 6. FileBrowser

### 6.1 Instalar
```bash
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
mkdir -p ~/archivos

filebrowser config init --database ~/.filebrowser.db
filebrowser config set --address 0.0.0.0 --port 8080 --root ~/archivos --database ~/.filebrowser.db
filebrowser users add admin TU_PASSWORD --database ~/.filebrowser.db
```

### 6.2 Servicio systemd
```bash
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
```

---

## 6.5 n8n (Automatización - Requiere Docker)

### 6.5.1 Crear configuración
```bash
mkdir -p ~/n8n-docker
cd ~/n8n-docker

cat > docker-compose.yml << 'EOF'
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.davidhub.space
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.davidhub.space/
      - GENERIC_TIMEZONE=America/Bogota
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF
```

### 6.5.2 Iniciar n8n
```bash
docker compose up -d
```

### 6.5.3 Exponer con Cloudflare Tunnel
```bash
# Crear registro DNS
cloudflared tunnel route dns finanzas n8n.davidhub.space

# Agregar al config del túnel
sudo nano /etc/cloudflared/config.yml
# Agregar antes de "- service: http_status:404":
#   - hostname: n8n.davidhub.space
#     service: http://localhost:5678

# Reiniciar túnel
sudo systemctl restart cloudflared
```

**Acceso:** https://n8n.davidhub.space

---

## 7. Desplegar App Laravel

### 7.1 Clonar y configurar
```bash
sudo mkdir -p /var/www/finanzas
sudo chown david:david /var/www/finanzas
cd /var/www/finanzas
git clone https://github.com/TU_USUARIO/finanzas.git .

composer install --optimize-autoloader --no-dev
npm install && npm run build

cp .env.example .env
nano .env  # Configurar APP_URL, DB_*, etc.
php artisan key:generate
php artisan migrate --seed
php artisan config:cache && php artisan route:cache && php artisan view:cache

sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

### 7.2 Nginx config
```bash
sudo nano /etc/nginx/sites-available/finanzas
```
```nginx
server {
    listen 80;
    server_name finanzas.davidhub.space;
    root /var/www/finanzas/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* { deny all; }
}
```
```bash
sudo ln -s /etc/nginx/sites-available/finanzas /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

---

## 8. Backups Automaticos

### 8.1 Clonar repo de backups
```bash
cd ~
git clone https://github.com/ROBOCOP3PK/finanzas-backups.git
```

### 8.2 Script de backup
```bash
nano ~/backup-db.sh
```
```bash
#!/bin/bash
FECHA=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR=~/finanzas-backups
DB_PATH=/var/www/finanzas/database/database.sqlite

cd $BACKUP_DIR
cp $DB_PATH database_$FECHA.sqlite
cp $DB_PATH database_latest.sqlite

git add .
git commit -m "Backup $FECHA"
git push origin main

ls -t database_2*.sqlite | tail -n +31 | xargs -r rm
```
```bash
chmod +x ~/backup-db.sh
```

### 8.3 Programar cron
```bash
crontab -e
# Agregar:
0 3 * * * /home/david/backup-db.sh >> /home/david/backup.log 2>&1
```

---

## 9. Restaurar desde Backup

Si tienes backup previo:
```bash
# Clonar repo de backups
git clone https://github.com/ROBOCOP3PK/finanzas-backups.git

# Restaurar base de datos
cp ~/finanzas-backups/database_latest.sqlite /var/www/finanzas/database/database.sqlite
sudo chown www-data:www-data /var/www/finanzas/database/database.sqlite
```

---

## 10. Verificacion Final

```bash
# Servicios corriendo
sudo systemctl status nginx php8.3-fpm cloudflared filebrowser

# Versiones
php -v && node -v && composer --version

# Temperatura
sensors

# Apps accesibles
curl -I http://localhost
curl -I http://localhost:8080
```

**URLs para probar:**
- https://finanzas.davidhub.space
- https://archivos.davidhub.space

---

## Troubleshooting

| Problema | Solucion |
|----------|----------|
| GRUB se queda colgado | Usar Ubuntu 22.04, no 24.04 |
| USB no bootea | Recrear con MBR + BIOS en Rufus |
| 502 Bad Gateway | `sudo systemctl restart php8.3-fpm` |
| Permisos storage | `sudo chmod -R 775 storage bootstrap/cache` |
| Tunel no conecta | `sudo systemctl restart cloudflared` |
| dubious ownership | `git config --global --add safe.directory /var/www/app` |

---

## WiFi (Opcional)

Si necesitas WiFi en lugar de ethernet:
```bash
sudo apt install network-manager -y
sudo nmcli dev wifi list
sudo nmcli connection add type wifi con-name "MiWifi" ifname wlp2s0b1 ssid "NOMBRE_RED" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "PASSWORD"
sudo nmcli connection up "MiWifi"
sudo nmcli connection modify "MiWifi" ipv4.dns "8.8.8.8 8.8.4.4"
```
