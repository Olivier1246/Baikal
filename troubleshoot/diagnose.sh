#!/bin/bash
# Diagnostic système complet Baïkal

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/var/www/baikal"
ISSUES=0

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Diagnostic complet Baïkal${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# 1. Services
echo -e "${YELLOW}1. Services:${NC}"
systemctl is-active --quiet nginx && echo -e "${GREEN}✓ Nginx actif${NC}" || { echo -e "${RED}✗ Nginx inactif${NC}"; ((ISSUES++)); }
systemctl is-active --quiet php*-fpm && echo -e "${GREEN}✓ PHP-FPM actif${NC}" || { echo -e "${RED}✗ PHP-FPM inactif${NC}"; ((ISSUES++)); }
echo ""

# 2. Permissions
echo -e "${YELLOW}2. Permissions:${NC}"
if [ -d "$INSTALL_DIR" ]; then
    OWNER=$(stat -c '%U:%G' "$INSTALL_DIR")
    [ "$OWNER" = "www-data:www-data" ] && echo -e "${GREEN}✓ Propriétaire correct${NC}" || { echo -e "${RED}✗ Propriétaire: $OWNER (devrait être www-data:www-data)${NC}"; ((ISSUES++)); }
    
    PERMS=$(stat -c '%a' "$INSTALL_DIR/Specific")
    [ "$PERMS" = "770" ] && echo -e "${GREEN}✓ Permissions Specific/ OK${NC}" || echo -e "${YELLOW}⚠ Permissions Specific/: $PERMS (devrait être 770)${NC}"
else
    echo -e "${RED}✗ $INSTALL_DIR introuvable${NC}"
    ((ISSUES++))
fi
echo ""

# 3. Base de données
echo -e "${YELLOW}3. Base de données:${NC}"
if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    echo -e "${GREEN}✓ Base SQLite présente${NC}"
    
    INTEGRITY=$(sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "PRAGMA integrity_check;" 2>&1 | tr -d '\n\r' | xargs)
    if [ "$INTEGRITY" = "ok" ]; then
        echo -e "${GREEN}✓ Intégrité: OK${NC}"
    else
        echo -e "${RED}✗ Intégrité: $INTEGRITY${NC}"
        ((ISSUES++))
    fi
    
    READABLE=$(sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "SELECT COUNT(*) FROM principals;" 2>&1)
    [[ "$READABLE" =~ ^[0-9]+$ ]] && echo -e "${GREEN}✓ Base lisible ($READABLE utilisateurs)${NC}" || { echo -e "${RED}✗ Erreur lecture base${NC}"; ((ISSUES++)); }
else
    echo -e "${YELLOW}⚠ Base SQLite non trouvée${NC}"
fi
echo ""

# 4. URIs Principals
echo -e "${YELLOW}4. URIs Principals:${NC}"
if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    MALFORMED=$(sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "SELECT COUNT(*) FROM principals WHERE uri NOT LIKE 'principals/%/%';" 2>/dev/null || echo "0")
    if [ "$MALFORMED" -gt 0 ]; then
        echo -e "${RED}✗ $MALFORMED URI(s) mal formé(s)${NC}"
        echo "  Exécuter: sudo ./troubleshoot/fix_principals.sh"
        ((ISSUES++))
    else
        echo -e "${GREEN}✓ Tous les URIs sont corrects${NC}"
    fi
fi
echo ""

# 5. Configuration Nginx
echo -e "${YELLOW}5. Configuration Nginx:${NC}"
if [ -f "/etc/nginx/sites-available/baikal" ]; then
    echo -e "${GREEN}✓ Config Nginx présente${NC}"
    nginx -t &>/dev/null && echo -e "${GREEN}✓ Config Nginx valide${NC}" || { echo -e "${RED}✗ Config Nginx invalide${NC}"; ((ISSUES++)); }
else
    echo -e "${RED}✗ Config Nginx absente${NC}"
    ((ISSUES++))
fi
echo ""

# 6. Logs erreurs
echo -e "${YELLOW}6. Logs récents (24h):${NC}"
if [ -f "/var/log/nginx/baikal_error.log" ]; then
    ERRORS=$(find /var/log/nginx/baikal_error.log -mtime -1 -exec wc -l {} \; 2>/dev/null | awk '{print $1}' || echo "0")
    [ "$ERRORS" -gt 0 ] && echo -e "${YELLOW}⚠ $ERRORS erreur(s) dans les logs${NC}" || echo -e "${GREEN}✓ Aucune erreur récente${NC}"
    
    [ "$ERRORS" -gt 0 ] && echo "  Voir: sudo tail -50 /var/log/nginx/baikal_error.log"
else
    echo -e "${YELLOW}⚠ Fichier log absent${NC}"
fi
echo ""

# 7. Connectivité
echo -e "${YELLOW}7. Connectivité:${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "200" ] && echo -e "${GREEN}✓ HTTP local accessible${NC}" || { echo -e "${RED}✗ HTTP code: $HTTP_CODE${NC}"; ((ISSUES++)); }
echo ""

# Résumé
echo -e "${BLUE}════════════════════════════════════════${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Aucun problème détecté !${NC}"
else
    echo -e "${RED}✗ $ISSUES problème(s) détecté(s)${NC}"
    echo ""
    echo "Scripts de correction disponibles:"
    echo "- ./troubleshoot/fix_permissions.sh"
    echo "- ./troubleshoot/fix_database.sh"
    echo "- ./troubleshoot/fix_principals.sh"
fi
echo -e "${BLUE}════════════════════════════════════════${NC}"
