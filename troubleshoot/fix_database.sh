#!/bin/bash
# Réparation base de données SQLite

set -e
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

DB_FILE="/var/www/baikal/Specific/db/db.sqlite"

if [ ! -f "$DB_FILE" ]; then
    log_error "Base de données non trouvée: $DB_FILE"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Diagnostic base de données${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

INTEGRITY=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>&1 | tr -d '\n\r' | xargs)
echo "Intégrité: $INTEGRITY"

if [ "$INTEGRITY" = "ok" ]; then
    log_info "Base de données en bon état!"
    exit 0
fi

log_error "Problème détecté dans la base de données"
echo ""
echo "Méthodes de réparation:"
echo "1) REINDEX (reconstruction index)"
echo "2) VACUUM (nettoyage)"
echo "3) Export/Import (reconstruction complète)"
read -p "Choix [1]: " METHOD
METHOD=${METHOD:-1}

log_step "Création backup..."
BACKUP_FILE="/var/backups/baikal/db_backup_$(date +%Y%m%d_%H%M%S).sqlite"
mkdir -p /var/backups/baikal
cp "$DB_FILE" "$BACKUP_FILE"
log_info "Backup: $BACKUP_FILE"

systemctl stop nginx php*-fpm

case $METHOD in
    1)
        log_step "REINDEX..."
        sqlite3 "$DB_FILE" "REINDEX;"
        ;;
    2)
        log_step "VACUUM..."
        sqlite3 "$DB_FILE" "VACUUM;"
        ;;
    3)
        log_step "Export/Import..."
        sqlite3 "$DB_FILE" .dump > /tmp/baikal_dump.sql
        rm "$DB_FILE"
        sqlite3 "$DB_FILE" < /tmp/baikal_dump.sql
        rm /tmp/baikal_dump.sql
        ;;
esac

chown www-data:www-data "$DB_FILE"
chmod 660 "$DB_FILE"

systemctl start php*-fpm nginx

INTEGRITY_AFTER=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>&1 | tr -d '\n\r' | xargs)
if [ "$INTEGRITY_AFTER" = "ok" ]; then
    log_info "✓ Base réparée avec succès!"
else
    log_error "Échec réparation. Restaurer backup: cp $BACKUP_FILE $DB_FILE"
    exit 1
fi
