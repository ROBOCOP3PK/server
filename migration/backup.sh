#!/bin/bash
# Backup del servidor antes de migrar/formatear
set -e

BACKUP_DIR="/home/david/migration-backup"
FECHA=$(date +%Y%m%d_%H%M%S)

echo "=== BACKUP DEL SERVIDOR - $FECHA ==="

rm -rf $BACKUP_DIR
mkdir -p $BACKUP_DIR/{apps,nginx,cloudflared,mysql,home}

# 1. Apps Laravel (.env + SQLite + git remote)
echo "[1/6] Apps web..."
for app in /var/www/*/; do
    app_name=$(basename "$app")
    [ "$app_name" = "html" ] && continue
    echo "  - $app_name"
    mkdir -p "$BACKUP_DIR/apps/$app_name"
    [ -f "$app/.env" ] && cp "$app/.env" "$BACKUP_DIR/apps/$app_name/"
    [ -f "$app/database/database.sqlite" ] && cp "$app/database/database.sqlite" "$BACKUP_DIR/apps/$app_name/"
    [ -d "$app/.git" ] && git -C "$app" remote get-url origin > "$BACKUP_DIR/apps/$app_name/git-remote.txt" 2>/dev/null || true
done

# 2. Nginx
echo "[2/6] Nginx configs..."
cp -r /etc/nginx/sites-available/* $BACKUP_DIR/nginx/ 2>/dev/null || true

# 3. Cloudflare Tunnel
echo "[3/6] Cloudflare Tunnel..."
cp /etc/cloudflared/config.yml $BACKUP_DIR/cloudflared/ 2>/dev/null || true
cp /etc/cloudflared/*.json $BACKUP_DIR/cloudflared/ 2>/dev/null || true
cp ~/.cloudflared/cert.pem $BACKUP_DIR/cloudflared/ 2>/dev/null || true

# 4. MySQL (si existe)
echo "[4/6] MySQL..."
if command -v mysql &> /dev/null; then
    databases=$(sudo mysql -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "^(information_schema|performance_schema|mysql|sys)$" || true)
    for db in $databases; do
        echo "  - $db"
        sudo mysqldump "$db" > "$BACKUP_DIR/mysql/$db.sql" 2>/dev/null || true
    done
fi

# 5. Crontab
echo "[5/6] Crontab..."
crontab -l > $BACKUP_DIR/home/crontab.txt 2>/dev/null || true

# 6. Home (scripts + FileBrowser)
echo "[6/6] Home..."
[ -f ~/backup-db.sh ] && cp ~/backup-db.sh $BACKUP_DIR/home/
[ -f ~/.filebrowser.db ] && cp ~/.filebrowser.db $BACKUP_DIR/home/

# Info del sistema
cat > $BACKUP_DIR/system-info.txt << EOF
Fecha: $FECHA
PHP: $(php -v 2>/dev/null | head -1 || echo "N/A")
Node: $(node -v 2>/dev/null || echo "N/A")
Composer: $(composer --version 2>/dev/null | head -1 || echo "N/A")
EOF

# Comprimir
echo ""
echo "Comprimiendo..."
cd /home/david
tar -czvf "migration-backup-$FECHA.tar.gz" migration-backup

echo ""
echo "=== COMPLETADO ==="
echo "Archivo: /home/david/migration-backup-$FECHA.tar.gz"
echo "Tamaño: $(du -h /home/david/migration-backup-$FECHA.tar.gz | cut -f1)"
echo ""
echo "Siguiente: Copiar a USB y ejecutar restore.sh en servidor nuevo"
