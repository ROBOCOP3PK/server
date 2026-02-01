# Server Daily - Referencia Rápida

## Conectar

**Red local:**
```bash
ssh david@192.168.1.182
```

**Remoto (Tailscale):**
```bash
ssh david@100.112.16.24
```
> Funciona desde cualquier lugar con Tailscale instalado.

---

## Crear Usuario para Despliegue

Crear usuario que pueda subir apps a producción sin acceso completo al sistema.

```bash
# 1. Crear usuario
sudo adduser invitado
# Ingresa contraseña y datos (Enter para saltar opcionales)

# 2. Agregar al grupo www-data
sudo usermod -aG www-data invitado

# 3. Permitir escritura en /var/www
sudo chmod -R g+w /var/www

# 4. Permitir reiniciar servicios (ejecutar sudo visudo y agregar al final):
invitado ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl restart php8.3-fpm, /usr/bin/systemctl reload nginx
```

**El usuario puede:**
- Crear carpetas en `/var/www/`
- Desplegar apps (composer, npm, etc.)
- Reiniciar nginx y php-fpm

**El usuario NO puede:**
- Instalar programas del sistema
- Modificar configs de otros usuarios
- Usar sudo para otras cosas

**Conexión del invitado:**
```bash
ssh invitado@100.112.16.24
```

---

## Desplegar Nueva App

```bash
# 1. Clonar
cd /var/www
sudo git clone https://github.com/TU_USUARIO/REPO.git nombre-app
sudo chown -R david:david /var/www/nombre-app
cd nombre-app

# 2. Dependencias
composer install --optimize-autoloader --no-dev
npm install && npm run build

# 3. Laravel
cp .env.example .env
nano .env  # APP_URL, DB_*, etc.
php artisan key:generate
php artisan migrate --seed

# 4. Permisos
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

### Nginx
```bash
sudo nano /etc/nginx/sites-available/nombre-app
```
```nginx
server {
    listen 80;
    server_name nombre-app.davidhub.space;
    root /var/www/nombre-app/public;
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
sudo ln -s /etc/nginx/sites-available/nombre-app /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Cloudflare Tunnel

**1. Crear registro DNS (CNAME) desde consola:**
```bash
cloudflared tunnel route dns finanzas nombre-app.davidhub.space
```
> Esto crea el CNAME en Cloudflare automáticamente. No necesitas entrar al dashboard web.

**2. Agregar hostname al config:**
```bash
sudo nano /etc/cloudflared/config.yml
# Agregar antes de "- service: http_status:404":
#   - hostname: nombre-app.davidhub.space
#     service: http://localhost:80
```

**3. Reiniciar túnel:**
```bash
sudo systemctl restart cloudflared
```

---

## Actualizar App Existente

```bash
cd /var/www/nombre-app
git pull
composer install --no-dev
npm install && npm run build
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan view:cache
sudo chown -R www-data:www-data storage bootstrap/cache
```

---

## MySQL (si aplica)

```bash
sudo mysql
```
```sql
CREATE DATABASE nombre_app;
CREATE USER 'user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON nombre_app.* TO 'user'@'localhost';
FLUSH PRIVILEGES;
```

---

## Comandos Útiles

```bash
# Estado servicios
sudo systemctl status nginx php8.3-fpm cloudflared

# Reiniciar
sudo systemctl restart nginx php8.3-fpm cloudflared

# Logs Laravel
tail -f /var/www/nombre-app/storage/logs/laravel.log

# Logs Nginx
sudo tail -f /var/log/nginx/error.log

# Logs Tunnel
sudo journalctl -u cloudflared -f

# Backup manual BD
~/backup-db.sh

# Temperatura
sensors
```

---

## Docker y n8n

### Comandos Docker
```bash
# Ver contenedores corriendo
docker ps

# Ver todos los contenedores (incluye detenidos)
docker ps -a

# Ver logs de un contenedor
docker logs nombre-contenedor

# Reiniciar contenedor
docker restart nombre-contenedor

# Detener contenedor
docker stop nombre-contenedor

# Eliminar contenedor
docker rm nombre-contenedor

# Ver imágenes descargadas
docker images

# Eliminar imagen
docker rmi nombre-imagen

# Espacio usado por Docker
docker system df

# Limpiar recursos no usados
docker system prune
```

### n8n (Automatización)
```bash
# Ir a carpeta de n8n
cd ~/n8n-docker

# Iniciar n8n
docker compose up -d

# Detener n8n
docker compose down

# Ver logs de n8n
docker logs n8n -f

# Reiniciar n8n
docker compose restart

# Actualizar n8n a última versión
docker compose pull
docker compose up -d
```

**Acceso:** https://n8n.davidhub.space (puerto 5678)

**Ubicación config:** `~/n8n-docker/docker-compose.yml`

---

## Timeshift (Snapshots del Sistema)

Primero instalar: `sudo apt install timeshift`

```bash
# Crear snapshot manual
sudo timeshift --create --comments "Descripcion del estado actual"

# Ver todos los snapshots
sudo timeshift --list

# Restaurar snapshot específico (te muestra lista para elegir)
sudo timeshift --restore

# Eliminar snapshot específico
sudo timeshift --delete --snapshot '2024-01-15_10-30-00'
```

**Ejemplo de uso:**
```bash
# Antes de dar acceso a alguien
sudo timeshift --create --comments "Antes de invitado"

# Si algo se daña, ver snapshots disponibles
sudo timeshift --list

# Restaurar (te pregunta cuál elegir)
sudo timeshift --restore
```

> Restaura: sistema, programas, configs. NO restaura bases de datos (usar backup de BD aparte).

---

## Problemas Comunes

| Problema | Solución |
|----------|----------|
| 502 Bad Gateway | `sudo systemctl restart php8.3-fpm` |
| Permisos storage | `sudo chmod -R 775 storage bootstrap/cache` |
| dubious ownership | `git config --global --add safe.directory /var/www/app` |
| Página en blanco | `tail -f storage/logs/laravel.log` |
| Assets no cargan | `npm run build` |
| Túnel no conecta | `sudo systemctl restart cloudflared` |
| n8n no responde | `cd ~/n8n-docker && docker compose restart` |
| Docker sin permisos | Cerrar sesión y volver a entrar (grupo docker) |
| Contenedor no inicia | `docker logs nombre-contenedor` |

---

## Apps Activas

| App | URL | Tipo |
|-----|-----|------|
| Finanzas | https://finanzas.davidhub.space | Laravel |
| Tienda | https://tienda.davidhub.space | Laravel |
| DeepDev | https://deepdev.davidhub.space | Laravel |
| Domicilios | https://domicilios.davidhub.space | Laravel |
| Archivos | https://archivos.davidhub.space | FileBrowser |
| n8n | https://n8n.davidhub.space | Docker |
