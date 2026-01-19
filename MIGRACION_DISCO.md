# Migración a Disco Nuevo (SSD)

Guía para cambiar el HDD del servidor por un SSD sin perder nada.

---

## Resumen

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PASO 1: Backup (servidor actual)                                       │
│  ─────────────────────────────────                                      │
│  Ejecutar backup.sh → genera .tar.gz con configs y datos                │
│                                                                         │
│  PASO 2: Cambiar disco                                                  │
│  ────────────────────                                                   │
│  Apagar servidor → poner SSD → instalar Ubuntu Server                   │
│                                                                         │
│  PASO 3: Restore (servidor nuevo)                                       │
│  ────────────────────────────────                                       │
│  Ejecutar restore.sh → instala todo y restaura configs                  │
│                                                                         │
│  Resultado: Servidor funcionando igual que antes, pero en SSD           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Archivos necesarios

Los scripts están en: `migration/`

```
migration/
├── backup.sh      # Genera el backup
├── restore.sh     # Restaura todo en servidor nuevo
└── README.md      # Referencia rápida
```

---

## Paso 1: Hacer Backup (en servidor actual)

### 1.1 Copiar scripts al servidor

Desde tu PC:
```bash
cd /home/david_gonzalez/personal_projects/vision
scp -r migration/ david@192.168.1.182:~/
```

### 1.2 Ejecutar backup

```bash
ssh david@192.168.1.182
cd ~/migration
chmod +x backup.sh
./backup.sh
```

Verás algo así:
```
======================================
  BACKUP DEL SERVIDOR - 20250115_143022
======================================
[1/7] Respaldando aplicaciones web...
  - finanzas
  - tienda
  - domicilios
[2/7] Respaldando configuración Nginx...
[3/7] Respaldando Cloudflare Tunnel...
[4/7] Respaldando bases de datos MySQL...
[5/7] Respaldando crontab...
[6/7] Respaldando archivos del home...
[7/7] Guardando información del sistema...

Comprimiendo backup...

======================================
  BACKUP COMPLETADO
======================================

Archivo: /home/david/migration-backup-20250115_143022.tar.gz
Tamaño: 2.3M
```

### 1.3 Copiar backup a tu PC o USB

```bash
# Opción A: A tu PC
scp david@192.168.1.182:~/migration-backup-*.tar.gz .

# Opción B: A USB (en el servidor)
sudo mount /dev/sdb1 /mnt
cp ~/migration-backup-*.tar.gz /mnt/
sudo umount /mnt
```

### Qué incluye el backup

| Elemento | Descripción |
|----------|-------------|
| `.env` de cada app | Configuración (DB, keys, URLs) |
| `database.sqlite` | Bases de datos SQLite |
| Dumps MySQL | Todas las bases de datos MySQL |
| Config Nginx | Archivos de cada sitio |
| Cloudflare Tunnel | Credenciales y config del túnel |
| Crontab | Tareas programadas (backups, etc.) |
| Scripts home | backup-db.sh, duckdns, etc. |

---

## Paso 2: Cambiar el Disco

### 2.1 Apagar servidor
```bash
sudo shutdown now
```

### 2.2 Cambiar disco físicamente
1. Desconectar cable de corriente
2. Abrir el portátil (tornillos de atrás)
3. Sacar HDD viejo
4. Poner SSD nuevo
5. Cerrar y conectar

### 2.3 Instalar Ubuntu Server

1. Crear USB booteable con Ubuntu Server 22.04 LTS (ver SERVER_PERSONAL.md sección 3)
2. Bootear desde USB (Esc → F9 en HP)
3. Durante instalación:
   - Usuario: `david`
   - Hostname: `homeserver`
   - Marcar "Install OpenSSH server"
4. Anotar la IP que le asigna

---

## Paso 3: Restaurar (en servidor nuevo)

### 3.1 Copiar backup al servidor nuevo

Desde tu PC:
```bash
scp migration-backup-*.tar.gz david@NUEVA_IP:~/
scp -r migration/ david@NUEVA_IP:~/
```

### 3.2 Descomprimir y ejecutar restore

```bash
ssh david@NUEVA_IP

# Descomprimir
cd ~
tar -xzvf migration-backup-*.tar.gz

# Ejecutar restore
cd ~/migration
chmod +x restore.sh
./restore.sh
```

El script hace todo automáticamente:
- Actualiza Ubuntu
- Instala Nginx, PHP 8.3, Node.js 20, Composer
- Instala MySQL (si había DBs)
- Clona las apps desde GitHub
- Restaura .env y bases de datos
- Configura Nginx (sites-available)
- Configura Cloudflare Tunnel
- Configura firewall (UFW) y Fail2ban
- Restaura crontab

### 3.3 Verificar

```bash
# Ver estado de servicios
sudo systemctl status nginx php8.3-fpm cloudflared

# Probar desde navegador
# https://finanzas.davidhub.space
```

---

## Paso 4: Ajustes Finales (si aplica)

### IP Estática (opcional)

Si quieres la misma IP que antes:
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.182/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```
```bash
sudo netplan apply
```

### FileBrowser (si lo usabas)

El restore no instala FileBrowser automáticamente. Instalarlo manualmente:
```bash
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
# Ver SERVER_PERSONAL.md sección 16 para config completa
```

### Archivos grandes (~/archivos)

Si tenías archivos grandes en `~/archivos`, cópialos por separado:
```bash
# Desde PC con ambos discos accesibles, o con rsync
rsync -avz --progress david@IP_VIEJA:~/archivos/ david@IP_NUEVA:~/archivos/
```

---

## Solución de Problemas

| Problema | Solución |
|----------|----------|
| Túnel no conecta | `sudo journalctl -u cloudflared -f` para ver logs |
| Apps no cargan | Verificar permisos: `sudo chown -R www-data:www-data /var/www/app/storage` |
| Error 502 | `sudo systemctl restart php8.3-fpm` |
| Git clone falla | Verificar acceso a GitHub (puede necesitar token) |
| MySQL no restaura | Verificar que el servicio esté activo: `sudo systemctl status mysql` |

---

## Checklist

### Antes del cambio
- [ ] Ejecutar `backup.sh` en servidor actual
- [ ] Copiar `migration-backup-*.tar.gz` a PC o USB
- [ ] Tener USB booteable con Ubuntu Server 22.04
- [ ] Anotar IP actual del servidor (por si la necesitas)

### Durante el cambio
- [ ] Apagar servidor
- [ ] Cambiar HDD por SSD
- [ ] Instalar Ubuntu Server (usuario: david)
- [ ] Anotar IP nueva

### Después del cambio
- [ ] Copiar backup al servidor nuevo
- [ ] Ejecutar `restore.sh`
- [ ] Verificar servicios (`systemctl status`)
- [ ] Probar apps desde navegador
- [ ] Configurar IP estática (opcional)
- [ ] Instalar FileBrowser (si lo usabas)
- [ ] Copiar ~/archivos (si tenías archivos grandes)

---

## Tiempo Estimado

| Paso | Tiempo |
|------|--------|
| Backup | 2-5 min |
| Cambiar disco | 10-15 min |
| Instalar Ubuntu | 15-20 min |
| Ejecutar restore | 10-15 min |
| Verificar todo | 5-10 min |
| **Total** | **~1 hora** |
