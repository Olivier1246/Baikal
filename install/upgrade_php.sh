#!/bin/bash

################################################################################
# Mise à jour PHP vers 8.2 ou 8.3
# Projet: Baïkal Install Suite
# Fichier: install/upgrade_php.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Mise à jour PHP pour Baïkal${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

CURRENT_PHP=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
log_info "Version PHP actuelle: $CURRENT_PHP"

if [[ $(echo "$CURRENT_PHP >= 8.2" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
    log_info "PHP $CURRENT_PHP est déjà compatible !"
    exit 0
fi

echo ""
echo "Quelle version installer ?"
echo "1) PHP 8.2 (Stable)"
echo "2) PHP 8.3 (Dernière)"
read -p "Choix [1]: " PHP_CHOICE
PHP_CHOICE=${PHP_CHOICE:-1}

[ "$PHP_CHOICE" = "1" ] && NEW_PHP="8.2" || NEW_PHP="8.3"

log_step "Ajout du repository PHP..."
apt-get update -qq
apt-get install -y software-properties-common
add-apt-repository ppa:ondrej/php -y
apt-get update -qq

log_step "Installation PHP $NEW_PHP..."
apt-get install -y \
    php${NEW_PHP} \
    php${NEW_PHP}-fpm \
    php${NEW_PHP}-cli \
    php${NEW_PHP}-common \
    php${NEW_PHP}-curl \
    php${NEW_PHP}-mbstring \
    php${NEW_PHP}-xml \
    php${NEW_PHP}-zip \
    php${NEW_PHP}-sqlite3 \
    php${NEW_PHP}-mysql \
    php${NEW_PHP}-gd \
    php${NEW_PHP}-intl

log_step "Configuration PHP..."
PHP_INI="/etc/php/${NEW_PHP}/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    cp "$PHP_INI" "${PHP_INI}.backup"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
fi

log_step "Mise à jour Nginx..."
sed -i "s|unix:/var/run/php/php.*-fpm.sock|unix:/var/run/php/php${NEW_PHP}-fpm.sock|g" \
    /etc/nginx/sites-available/baikal

update-alternatives --set php /usr/bin/php${NEW_PHP}

[ ! -z "$CURRENT_PHP" ] && systemctl stop php${CURRENT_PHP}-fpm 2>/dev/null || true

systemctl enable php${NEW_PHP}-fpm
systemctl start php${NEW_PHP}-fpm
nginx -t && systemctl restart nginx

echo ""
log_info "════════════════════════════════════════"
log_info "✓ Mise à jour PHP terminée !"
log_info "════════════════════════════════════════"
echo "Ancienne: PHP $CURRENT_PHP"
echo "Nouvelle: PHP $NEW_PHP"

