#!/bin/bash
# Correction permissions Baïkal

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

INSTALL_DIR="/var/www/baikal"

log_step "Arrêt Nginx..."
systemctl stop nginx

log_step "Correction propriétaire..."
chown -R www-data:www-data "$INSTALL_DIR"

log_step "Correction permissions..."
find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
find "$INSTALL_DIR" -type f -exec chmod 644 {} \;

chmod -R 770 "$INSTALL_DIR/Specific"
chmod -R 770 "$INSTALL_DIR/config"

if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    chmod 660 "$INSTALL_DIR/Specific/db/db.sqlite"
fi

log_step "Redémarrage Nginx..."
systemctl start nginx

log_info "✓ Permissions corrigées avec succès!"
