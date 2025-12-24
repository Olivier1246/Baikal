#!/bin/bash
# Script de backup Baïkal

GREEN='\033[0;32m'
NC='\033[0m'

BAIKAL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

mkdir -p "$BACKUP_DIR"
log_info "Création backup Baïkal..."

tar -czf "$BACKUP_DIR/baikal_data_$DATE.tar.gz" -C "$BAIKAL_DIR" Specific config 2>/dev/null || true

[ -f "$BAIKAL_DIR/Specific/db/db.sqlite" ] && cp "$BAIKAL_DIR/Specific/db/db.sqlite" "$BACKUP_DIR/baikal_db_$DATE.sqlite"

[ -f "/etc/nginx/sites-available/baikal" ] && cp /etc/nginx/sites-available/baikal "$BACKUP_DIR/nginx_baikal_$DATE.conf"

find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_info "Backup terminé! Taille totale: $BACKUP_SIZE"
