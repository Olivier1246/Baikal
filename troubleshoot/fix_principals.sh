#!/bin/bash
# Correction URIs principals

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

DB_FILE="/var/www/baikal/Specific/db/db.sqlite"

log_step "Détection principals malformés..."
MALFORMED=$(sqlite3 "$DB_FILE" "SELECT uri, displayname FROM principals WHERE uri NOT LIKE 'principals/%/%';" 2>/dev/null)

if [ -z "$MALFORMED" ]; then
    log_info "Tous les URIs sont corrects!"
    exit 0
fi

echo "Utilisateurs affectés:"
echo "$MALFORMED"
echo ""

read -p "Corriger ces URIs ? (o/n): " CONFIRM
[ "$CONFIRM" != "o" ] && exit 0

log_step "Création backup..."
BACKUP="/var/backups/baikal/db_principals_$(date +%Y%m%d_%H%M%S).sqlite"
mkdir -p /var/backups/baikal
cp "$DB_FILE" "$BACKUP"
log_info "Backup: $BACKUP"

systemctl stop nginx php*-fpm

log_step "Correction URIs..."
sqlite3 "$DB_FILE" << SQL
UPDATE principals 
SET uri = 'principals/users/' || LOWER(REPLACE(uri, 'principals/', '')) || '/'
WHERE uri NOT LIKE 'principals/%/%';

UPDATE calendars 
SET principaluri = REPLACE(principaluri, 'principals/', 'principals/users/')
WHERE principaluri NOT LIKE 'principals/%/%';

UPDATE addressbooks
SET principaluri = REPLACE(principaluri, 'principals/', 'principals/users/')  
WHERE principaluri NOT LIKE 'principals/%/%';
SQL

chown www-data:www-data "$DB_FILE"
chmod 660 "$DB_FILE"

systemctl start php*-fpm nginx

log_info "✓ URIs corrigés!"
log_warn "Reconfigurez vos clients avec les nouvelles URLs:"
DOMAIN=$(grep server_name /etc/nginx/sites-available/baikal | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')
echo "CalDAV: http://$DOMAIN/dav.php"
echo "CardDAV: http://$DOMAIN/dav.php"
