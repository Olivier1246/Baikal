#!/bin/bash

################################################################################
# Diagnostic et correction PHP-FPM pour Baïkal
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Diagnostic PHP-FPM${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Détecter la version PHP installée
echo "Versions PHP installées:"
dpkg -l | grep "^ii" | grep "php[0-9].*-fpm" | awk '{print $2}' | cut -d'-' -f1 | sort -u

echo ""
echo "Services PHP-FPM disponibles:"
systemctl list-unit-files | grep php.*fpm

echo ""
echo "Version PHP CLI par défaut:"
php -v | head -1

echo ""
echo "Services PHP-FPM actifs:"
systemctl list-units --type=service --state=running | grep php

echo ""
echo "Services PHP-FPM inactifs:"
systemctl list-units --type=service --state=inactive | grep php

echo ""
echo -e "${YELLOW}Quelle version PHP-FPM devrait être active ?${NC}"
echo ""

# Trouver la version configurée dans Nginx
NGINX_PHP=$(grep -r "fastcgi_pass.*php.*-fpm.sock" /etc/nginx/sites-available/baikal 2>/dev/null | grep -oP "php[0-9.]+(?=-fpm)" | head -1)

if [ ! -z "$NGINX_PHP" ]; then
    echo -e "${GREEN}Nginx utilise: ${NGINX_PHP}-fpm${NC}"
    
    # Vérifier si ce service existe
    if systemctl list-unit-files | grep -q "${NGINX_PHP}-fpm"; then
        echo -e "${GREEN}Service ${NGINX_PHP}-fpm trouvé${NC}"
        
        # Vérifier s'il est actif
        if systemctl is-active --quiet ${NGINX_PHP}-fpm; then
            echo -e "${GREEN}✓ ${NGINX_PHP}-fpm est déjà actif${NC}"
        else
            echo -e "${YELLOW}${NGINX_PHP}-fpm est inactif, démarrage...${NC}"
            
            if [ "$EUID" -ne 0 ]; then
                echo -e "${RED}Vous devez être root pour démarrer les services${NC}"
                echo "Lancez: sudo systemctl start ${NGINX_PHP}-fpm"
            else
                systemctl enable ${NGINX_PHP}-fpm
                systemctl start ${NGINX_PHP}-fpm
                
                if systemctl is-active --quiet ${NGINX_PHP}-fpm; then
                    echo -e "${GREEN}✓ ${NGINX_PHP}-fpm démarré avec succès${NC}"
                else
                    echo -e "${RED}✗ Échec du démarrage de ${NGINX_PHP}-fpm${NC}"
                    echo ""
                    echo "Consultez les logs:"
                    echo "  journalctl -u ${NGINX_PHP}-fpm -n 20"
                fi
            fi
        fi
    else
        echo -e "${RED}Service ${NGINX_PHP}-fpm introuvable !${NC}"
        echo ""
        echo "Installez-le avec:"
        echo "  sudo apt install ${NGINX_PHP}-fpm"
    fi
else
    echo -e "${YELLOW}Impossible de détecter la version PHP depuis Nginx${NC}"
    echo ""
    echo "Versions PHP-FPM installées:"
    dpkg -l | grep "^ii" | grep "php[0-9].*-fpm" | awk '{print $2}'
    echo ""
    echo "Vérifiez /etc/nginx/sites-available/baikal"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}État final des services${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Status Nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx: Actif${NC}"
else
    echo -e "${RED}✗ Nginx: Inactif${NC}"
fi

# Status PHP-FPM
PHP_FPM_RUNNING=$(systemctl list-units --type=service --state=running | grep "php.*fpm" | awk '{print $1}')
if [ ! -z "$PHP_FPM_RUNNING" ]; then
    echo -e "${GREEN}✓ PHP-FPM: $PHP_FPM_RUNNING${NC}"
else
    echo -e "${RED}✗ PHP-FPM: Aucun service actif${NC}"
fi

echo ""
