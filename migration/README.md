# Migracion de Servidor

Scripts para migrar el servidor a disco nuevo (SSD).

## Uso

### 1. En servidor actual
```bash
cd ~/migration
./backup.sh
```
Genera: `/home/david/migration-backup-FECHA.tar.gz`

### 2. Copiar a USB
```bash
sudo mount /dev/sdb1 /mnt
cp ~/migration-backup-*.tar.gz /mnt/
sudo umount /mnt
```

### 3. En servidor nuevo
```bash
# Instalar Ubuntu Server 22.04 LTS (usuario: david)
# Copiar backup y scripts

tar -xzvf migration-backup-*.tar.gz
./restore.sh
```

## Que respalda backup.sh

| Elemento | Origen |
|----------|--------|
| Apps (.env + SQLite) | `/var/www/*` |
| Nginx configs | `/etc/nginx/sites-available/*` |
| Cloudflare Tunnel | `/etc/cloudflared/*` |
| MySQL dumps | todas las DBs |
| Crontab | tareas programadas |
| FileBrowser DB | `~/.filebrowser.db` |
| Scripts | `~/backup-db.sh` |

## Que instala restore.sh

- Nginx + PHP 8.3 + Composer + Node.js 20
- MySQL (si habia DBs)
- Git, UFW, Fail2ban, lm-sensors
- Cloudflare Tunnel
- FileBrowser
- Configura logind.conf (no suspender al cerrar tapa)

## Notas

- **~/archivos/**: Copiar manualmente con rsync si hay archivos grandes
- **Git**: El script clona desde GitHub (necesitas acceso)
- **FileBrowser nuevo**: Crear usuario despues de restaurar
