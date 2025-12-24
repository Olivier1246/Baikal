#!/bin/bash

################################################################################
# Script de monitoring Baïkal - Version finale corrigée
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal"
LOG_DIR="/var/log/nginx"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Monitoring Baïkal - Version améliorée${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# 1. Services
# ============================================
echo -e "${YELLOW}Services:${NC}"

# Nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx: Actif${NC}"
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    echo "  Version: $NGINX_VERSION"
else
    echo -e "${RED}✗ Nginx: Inactif${NC}"
fi

# PHP-FPM - Détection automatique de la version active
PHP_FPM_SERVICE=$(systemctl list-units --type=service --state=running | grep "php.*fpm" | awk '{print $1}' | head -1)
if [ ! -z "$PHP_FPM_SERVICE" ]; then
    echo -e "${GREEN}✓ PHP-FPM: Actif ($PHP_FPM_SERVICE)${NC}"
    PHP_VERSION=$(echo "$PHP_FPM_SERVICE" | grep -oP "php[0-9.]+")
    if [ ! -z "$PHP_VERSION" ]; then
        PHP_FULL_VERSION=$($PHP_VERSION -v 2>/dev/null | head -1 | cut -d' ' -f2)
        echo "  Version: $PHP_FULL_VERSION"
    fi
else
    echo -e "${RED}✗ PHP-FPM: Inactif${NC}"
    echo -e "${YELLOW}  Pour corriger: sudo ./fix_php_fpm_service.sh${NC}"
fi

echo ""

# ============================================
# 2. Espace disque
# ============================================
echo -e "${YELLOW}Espace disque:${NC}"

df -h / | tail -1 | awk '{
    used=$5+0
    if (used < 80) 
        printf "'"${GREEN}"'✓ Espace disque (/): %s utilisé'"${NC}"'\n", $5
    else if (used < 90)
        printf "'"${YELLOW}"'⚠ Espace disque (/): %s utilisé'"${NC}"'\n", $5
    else
        printf "'"${RED}"'✗ Espace disque (/): %s utilisé'"${NC}"'\n", $5
}'

if [ -d "/var/www" ]; then
    df -h /var/www | tail -1 | awk '{
        used=$5+0
        if (used < 80)
            printf "'"${GREEN}"'✓ Espace disque (/var/www): %s utilisé'"${NC}"'\n", $5
        else
            printf "'"${YELLOW}"'⚠ Espace disque (/var/www): %s utilisé'"${NC}"'\n", $5
    }'
fi

if [ -d "/var/backups" ]; then
    df -h /var/backups | tail -1 | awk '{
        used=$5+0
        if (used < 80)
            printf "'"${GREEN}"'✓ Espace disque (/var/backups): %s utilisé'"${NC}"'\n", $5
        else
            printf "'"${YELLOW}"'⚠ Espace disque (/var/backups): %s utilisé'"${NC}"'\n", $5
    }'
fi

echo ""

# ============================================
# 3. Base de données - CORRIGÉ
# ============================================
echo -e "${YELLOW}Base de données:${NC}"

if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    DB_SIZE=$(du -sh "$INSTALL_DIR/Specific/db/db.sqlite" | cut -f1)
    echo -e "${GREEN}✓ SQLite: Base trouvée ($DB_SIZE)${NC}"
    
    # Intégrité de la base - CORRECTION DU BUG
    INTEGRITY_RAW=$(sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "PRAGMA integrity_check;" 2>/dev/null)
    # Nettoyer les retours à la ligne et espaces
    INTEGRITY=$(echo "$INTEGRITY_RAW" | tr -d '\n' | tr -d '\r' | xargs)
    
    if [ "$INTEGRITY" = "ok" ]; then
        echo -e "${GREEN}  Intégrité: OK${NC}"
    else
        echo -e "${RED}  Intégrité: Problème détecté${NC}"
        echo -e "${YELLOW}  Lancez: sudo ./diagnose_sqlite_db.sh${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SQLite: Base non trouvée${NC}"
fi

echo ""

# ============================================
# 4. Logs récents
# ============================================
echo -e "${YELLOW}Logs (dernières 24h):${NC}"

# Logs Nginx
if [ -f "$LOG_DIR/baikal_error.log" ]; then
    ERROR_COUNT=$(grep -c "error" "$LOG_DIR/baikal_error.log" 2>/dev/null || echo "0")
    # Nettoyer les caractères spéciaux
    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n\r' | xargs)
    
    # Vérifier que c'est un nombre
    if [[ "$ERROR_COUNT" =~ ^[0-9]+$ ]]; then
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠ Nginx erreurs: $ERROR_COUNT dans les dernières 24h${NC}"
            echo "  Dernière erreur:"
            tail -1 "$LOG_DIR/baikal_error.log" | sed 's/^/  /'
        else
            echo -e "${GREEN}✓ Nginx erreurs: Aucune${NC}"
        fi
    else
        echo -e "${GREEN}✓ Nginx erreurs: Aucune${NC}"
    fi
elif [ -f "$LOG_DIR/error.log" ]; then
    ERROR_COUNT=$(grep -c "baikal" "$LOG_DIR/error.log" 2>/dev/null || echo "0")
    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n\r' | xargs)
    echo -e "${YELLOW}⚠ Logs dans $LOG_DIR/error.log ($ERROR_COUNT entrées)${NC}"
else
    echo -e "${YELLOW}⚠ Logs Nginx: Fichier introuvable${NC}"
    echo "  Logs possibles: ls -la /var/log/nginx/"
fi

# Logs PHP-FPM
if [ ! -z "$PHP_FPM_SERVICE" ]; then
    PHP_ERRORS=$(journalctl -u "$PHP_FPM_SERVICE" --since "24 hours ago" 2>/dev/null | grep -ci "error" || echo "0")
    PHP_ERRORS=$(echo "$PHP_ERRORS" | tr -d '\n\r' | xargs)
    
    if [[ "$PHP_ERRORS" =~ ^[0-9]+$ ]] && [ "$PHP_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ PHP-FPM erreurs: $PHP_ERRORS dans les dernières 24h${NC}"
    else
        echo -e "${GREEN}✓ PHP-FPM: Aucune erreur${NC}"
    fi
fi

echo ""

# ============================================
# 5. Statistiques d'utilisation
# ============================================
echo -e "${YELLOW}Statistiques d'utilisation:${NC}"

if [ -f "$LOG_DIR/baikal_access.log" ]; then
    TODAY_REQUESTS=$(grep "$(date +%d/%b/%Y)" "$LOG_DIR/baikal_access.log" | wc -l)
    echo -e "${GREEN}✓ Requêtes aujourd'hui: $TODAY_REQUESTS${NC}"
    
    # Top IPs
    echo "  Top 3 IPs:"
    grep "$(date +%d/%b/%Y)" "$LOG_DIR/baikal_access.log" 2>/dev/null | \
        awk '{print $1}' | sort | uniq -c | sort -rn | head -3 | \
        sed 's/^/    /'
elif [ -f "$LOG_DIR/access.log" ]; then
    TODAY_REQUESTS=$(grep "$(date +%d/%b/%Y)" "$LOG_DIR/access.log" | grep -c "baikal" || echo "0")
    echo -e "${GREEN}✓ Requêtes Baïkal aujourd'hui: $TODAY_REQUESTS${NC}"
else
    echo -e "${YELLOW}⚠ Log d'accès introuvable${NC}"
fi

echo ""

# ============================================
# 6. Certificat SSL
# ============================================
echo -e "${YELLOW}Certificat SSL:${NC}"

DOMAIN=$(grep "server_name" /etc/nginx/sites-available/baikal | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')

if [ ! -z "$DOMAIN" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/cert.pem | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -gt 30 ]; then
        echo -e "${GREEN}✓ $DOMAIN: Expire dans $DAYS_LEFT jours${NC}"
    elif [ $DAYS_LEFT -gt 7 ]; then
        echo -e "${YELLOW}⚠ $DOMAIN: Expire dans $DAYS_LEFT jours${NC}"
        echo "  Renouveler: sudo certbot renew"
    else
        echo -e "${RED}✗ $DOMAIN: Expire dans $DAYS_LEFT jours !${NC}"
        echo "  URGENT: sudo certbot renew"
    fi
else
    echo -e "${YELLOW}⚠ Certificat SSL non trouvé ou pas de domaine configuré${NC}"
fi

echo ""

# ============================================
# 7. Backups
# ============================================
echo -e "${YELLOW}Backups:${NC}"

if [ -d "$BACKUP_DIR" ]; then
    LATEST_BACKUP=$(find "$BACKUP_DIR" -name "baikal_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)
    
    if [ ! -z "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d' ' -f1)
        BACKUP_SIZE=$(du -sh "$LATEST_BACKUP" | cut -f1)
        BACKUP_AGE_DAYS=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 86400 ))
        
        if [ $BACKUP_AGE_DAYS -le 1 ]; then
            echo -e "${GREEN}✓ Dernier backup: $BACKUP_DATE ($BACKUP_SIZE)${NC}"
        elif [ $BACKUP_AGE_DAYS -le 7 ]; then
            echo -e "${YELLOW}⚠ Dernier backup: il y a $BACKUP_AGE_DAYS jours ($BACKUP_SIZE)${NC}"
        else
            echo -e "${RED}✗ Dernier backup: il y a $BACKUP_AGE_DAYS jours ($BACKUP_SIZE)${NC}"
            echo "  Lancez: sudo /usr/local/bin/backup_baikal.sh"
        fi
        
        # Nombre total de backups
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "baikal_*.tar.gz" -type f | wc -l)
        echo "  Total backups: $BACKUP_COUNT"
    else
        echo -e "${YELLOW}⚠ Aucun backup trouvé${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Répertoire de backup non trouvé${NC}"
fi

echo ""

# ============================================
# 8. Connectivité
# ============================================
echo -e "${YELLOW}Connectivité:${NC}"

# Test local
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Accès local: OK${NC}"
else
    echo -e "${RED}✗ Accès local: Échec${NC}"
fi

# Port HTTPS - utiliser ss au lieu de netstat
if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":443 "; then
        echo -e "${GREEN}✓ Port HTTPS 443: Ouvert${NC}"
    else
        echo -e "${YELLOW}⚠ Port HTTPS 443: Fermé ou non détecté${NC}"
    fi
fi

# Test externe (si domaine configuré)
if [ ! -z "$DOMAIN" ]; then
    if curl -s -o /dev/null -w "%{http_code}" -k "https://$DOMAIN/" 2>/dev/null | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✓ Accès externe ($DOMAIN): OK${NC}"
    else
        echo -e "${YELLOW}⚠ Accès externe ($DOMAIN): Vérifiez le pare-feu/DNS${NC}"
    fi
fi

echo ""

# ============================================
# 9. Permissions
# ============================================
echo -e "${YELLOW}Permissions:${NC}"

if [ -d "$INSTALL_DIR/Specific" ]; then
    SPECIFIC_PERMS=$(stat -c %a "$INSTALL_DIR/Specific")
    if [ "$SPECIFIC_PERMS" = "770" ] || [ "$SPECIFIC_PERMS" = "775" ]; then
        echo -e "${GREEN}✓ Permissions Specific: OK ($SPECIFIC_PERMS)${NC}"
    else
        echo -e "${YELLOW}⚠ Permissions Specific: $SPECIFIC_PERMS (recommandé: 770)${NC}"
    fi
fi

if [ -d "$INSTALL_DIR/config" ]; then
    CONFIG_PERMS=$(stat -c %a "$INSTALL_DIR/config")
    if [ "$CONFIG_PERMS" = "770" ] || [ "$CONFIG_PERMS" = "775" ]; then
        echo -e "${GREEN}✓ Permissions config: OK ($CONFIG_PERMS)${NC}"
    else
        echo -e "${YELLOW}⚠ Permissions config: $CONFIG_PERMS (recommandé: 770)${NC}"
    fi
fi

# Propriétaire
OWNER=$(stat -c %U:%G "$INSTALL_DIR" 2>/dev/null)
if [ "$OWNER" = "www-data:www-data" ]; then
    echo -e "${GREEN}✓ Propriétaire: $OWNER${NC}"
else
    echo -e "${YELLOW}⚠ Propriétaire: $OWNER (recommandé: www-data:www-data)${NC}"
fi

echo ""

# ============================================
# Résumé
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Résumé${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Compter les problèmes
PROBLEMS=0

if ! systemctl is-active --quiet nginx; then
    ((PROBLEMS++))
fi

if [ -z "$PHP_FPM_SERVICE" ]; then
    ((PROBLEMS++))
fi

if [ ! -z "$LATEST_BACKUP" ] && [ $BACKUP_AGE_DAYS -gt 7 ]; then
    ((PROBLEMS++))
fi

if [ ! -z "$DAYS_LEFT" ] && [ $DAYS_LEFT -lt 7 ]; then
    ((PROBLEMS++))
fi

if [ "$INTEGRITY" != "ok" ]; then
    ((PROBLEMS++))
fi

if [ $PROBLEMS -eq 0 ]; then
    echo -e "${GREEN}✓ Système opérationnel - Aucun problème détecté${NC}"
else
    echo -e "${YELLOW}⚠ $PROBLEMS problème(s) détecté(s)${NC}"
fi

echo ""
echo "Pour plus de détails, consultez:"
echo "- Logs Nginx: /var/log/nginx/"
echo "- Logs système: journalctl -u nginx -u php*-fpm"
echo "- Interface web: https://$DOMAIN/"
echo ""
echo "Commandes de maintenance:"
echo "- Redémarrer Nginx: sudo systemctl restart nginx"
echo "- Redémarrer PHP-FPM: sudo systemctl restart php*-fpm"
echo "- Backup manuel: sudo /usr/local/bin/backup_baikal.sh"
echo "- Renouveler SSL: sudo certbot renew"
echo "- Diagnostic DB: sudo ./diagnose_sqlite_db.sh"
echo "- Réparer DB: sudo ./repair_sqlite_db.sh"
echo ""
