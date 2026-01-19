# Server Context

> Datos del servidor para dar contexto en conversaciones con IA.

## Hardware

| Componente | Valor |
|------------|-------|
| Modelo | HP G42 (~2010) |
| CPU | Intel Core i5 |
| RAM | 3 GB DDR3 |
| Disco | 500 GB HDD |
| SO | Ubuntu Server 22.04 LTS |

## Red

| Dato | Valor |
|------|-------|
| Usuario | `david` |
| Hostname | `homeserver` |
| IP Local | `192.168.1.182` |
| SSH | `ssh david@192.168.1.182` |
| Zona horaria | America/Bogota |

## Stack

| Software | Version |
|----------|---------|
| Nginx | 1.18.0 |
| PHP-FPM | 8.3.29 |
| Composer | 2.9.2 |
| Node.js | 20.19.6 |
| NPM | 10.8.2 |
| Git | 2.34.1 |
| SQLite | Principal |
| MySQL | 8.0 (opcional) |

## Cloudflare Tunnel

| Dato | Valor |
|------|-------|
| Dominio | `davidhub.space` |
| Tunel ID | `490bf84b-45b4-47af-bc64-f750b6372f88` |
| Nombre | `finanzas` |
| Config | `/etc/cloudflared/config.yml` |
| Registrador | Hostinger |
| Nameservers | `chuck.ns.cloudflare.com`, `gwen.ns.cloudflare.com` |

## Apps Desplegadas

| Subdominio | App | Puerto |
|------------|-----|--------|
| finanzas.davidhub.space | Finanzas (Laravel 12 + Vue 3) | 80 |
| tienda.davidhub.space | Tienda (Laravel) | 80 |
| domicilios.davidhub.space | Domicilios (Laravel) | 80 |
| archivos.davidhub.space | FileBrowser | 8080 |

## Estructura

```
/var/www/
├── finanzas/
├── tienda/
├── domicilios/
└── [nuevas-apps]/

/etc/nginx/sites-available/   # Configs Nginx
/etc/cloudflared/             # Config tunnel
/home/david/archivos/         # FileBrowser storage
```

## Servicios

| Servicio | Puerto | Estado |
|----------|--------|--------|
| SSH | 22 | Activo |
| Nginx | 80, 443 | Activo |
| PHP-FPM | socket | Activo |
| FileBrowser | 8080 | Activo |
| cloudflared | - | Activo |

## Seguridad

- **UFW**: OpenSSH + Nginx Full
- **Fail2ban**: Activo (SSH + Nginx)
- **SSL**: Automatico via Cloudflare

## Backups

| Aspecto | Valor |
|---------|-------|
| Contenido | database.sqlite |
| Destino | GitHub `finanzas-backups` |
| Frecuencia | Diaria 3:00 AM |
| Script | `~/backup-db.sh` |
