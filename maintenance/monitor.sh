#!/bin/bash
# Monitoring système Baïkal - Version consolidée

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Monitoring Baïkal${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Services
echo -e "${YELLOW}Services:${NC}"
systemctl is-active --quiet nginx && echo -e "${GREEN}✓ Nginx: Actif${NC}" || echo -e "${RED}✗ Nginx: Inactif${NC}"
PHP_FPM=$(systemctl list-units | grep php.*fpm.*running | awk '{print $1}' | head -1)
[ ! -z "$PHP_FPM" ] && echo -e "${GREEN}✓ PHP-FPM: Actif ($PHP_FPM)${NC}" || echo -e "${RED}✗ PHP-FPM: Inactif${NC}"
echo ""

# Espace disque
echo -e "${YELLOW}Espace disque:${NC}"
df -h / | awk 'NR==2 {if ($5+0 < 80) print "'"${GREEN}"'✓ / : "$5" utilisé'"${NC}"'; else print "'"${YELLOW}"'⚠ / : "$5" utilisé'"${NC}"'"}'
df -h /var/www 2>/dev/null | awk 'NR==2 {print "  /var/www: "$5" utilisé"}'
echo ""

# Base de données
echo -e "${YELLOW}Base de données:${NC}"
if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    DB_SIZE=$(du -sh "$INSTALL_DIR/Specific/db/db.sqlite" | cut -f1)
    echo -e "${GREEN}✓ SQLite: $DB_SIZE${NC}"
    INTEGRITY=$(sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "PRAGMA integrity_check;" 2>&1 | tr -d '\n\r' | xargs)
    [ "$INTEGRITY" = "ok" ] && echo -e "  Intégrité: ${GREEN}OK${NC}" || echo -e "  Intégrité: ${YELLOW}À vérifier${NC}"
fi
echo ""

# Certificat SSL
echo -e "${YELLOW}Certificat SSL:${NC}"
DOMAIN=$(grep "server_name" /etc/nginx/sites-available/baikal 2>/dev/null | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')
if [ ! -z "$DOMAIN" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/cert.pem 2>/dev/null | cut -d= -f2)
    DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
    [ $DAYS_LEFT -gt 30 ] && echo -e "${GREEN}✓ Expire dans $DAYS_LEFT jours${NC}" || echo -e "${YELLOW}⚠ Expire dans $DAYS_LEFT jours${NC}"
else
    echo -e "${YELLOW}⚠ Pas de certificat SSL${NC}"
fi
echo ""

# Backups
echo -e "${YELLOW}Backups:${NC}"
if [ -d "$BACKUP_DIR" ]; then
    LATEST=$(find "$BACKUP_DIR" -name "baikal_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)
    if [ ! -z "$LATEST" ]; then
        BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 86400 ))
        BACKUP_SIZE=$(du -sh "$LATEST" | cut -f1)
        [ $BACKUP_AGE -le 1 ] && echo -e "${GREEN}✓ Dernier backup: il y a $BACKUP_AGE jour(s) ($BACKUP_SIZE)${NC}" || echo -e "${YELLOW}⚠ Dernier backup: il y a $BACKUP_AGE jours${NC}"
    else
        echo -e "${YELLOW}⚠ Aucun backup trouvé${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Répertoire backups introuvable${NC}"
fi
echo ""

echo "Pour plus de détails: sudo ./troubleshoot/diagnose.sh"
