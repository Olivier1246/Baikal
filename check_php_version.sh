#!/bin/bash

################################################################################
# Vérification rapide de la version PHP
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "════════════════════════════════════════"
echo "Vérification PHP pour Baïkal"
echo "════════════════════════════════════════"
echo ""

# Version PHP CLI
echo "PHP CLI:"
php -v | head -1

# Version PHP-FPM actives
echo ""
echo "PHP-FPM actifs:"
systemctl list-units --type=service --state=running | grep php-fpm || echo "Aucun"

# Sockets PHP disponibles
echo ""
echo "Sockets PHP disponibles:"
ls -la /var/run/php/php*-fpm.sock 2>/dev/null || echo "Aucun"

# Configuration Nginx
echo ""
echo "Socket PHP utilisé dans Nginx:"
grep "fastcgi_pass" /etc/nginx/sites-available/baikal | grep -v "#"

# Version requise pour Baïkal 0.11.1
echo ""
echo "════════════════════════════════════════"
CURRENT_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="8.2"

echo "Version actuelle: $CURRENT_VERSION"
echo "Version requise: >= $REQUIRED_VERSION"

if command -v bc &> /dev/null; then
    if (( $(echo "$CURRENT_VERSION >= $REQUIRED_VERSION" | bc -l) )); then
        echo -e "${GREEN}✓ Version PHP compatible${NC}"
    else
        echo -e "${RED}✗ Version PHP trop ancienne${NC}"
        echo ""
        echo "Pour mettre à jour:"
        echo "  sudo ./upgrade_php.sh"
    fi
else
    echo "Note: Installez 'bc' pour la comparaison de versions"
fi

echo ""
