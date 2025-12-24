#!/bin/bash

################################################################################
# Mise à jour de PHP pour Baïkal 0.11.1
# Baïkal 0.11.1 nécessite PHP >= 8.2.0
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[ÉTAPE]${NC} $1"
}

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         MISE À JOUR PHP POUR BAÏKAL 0.11.1               ║
║         PHP 8.2 ou 8.3 requis                            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Détecter la version PHP actuelle
log_step "Détection de la version PHP actuelle..."
CURRENT_PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
log_info "Version PHP actuelle: $CURRENT_PHP_VERSION"

# Vérifier si upgrade nécessaire
if [[ $(echo "$CURRENT_PHP_VERSION >= 8.2" | bc -l) -eq 1 ]]; then
    log_info "PHP $CURRENT_PHP_VERSION est déjà compatible avec Baïkal 0.11.1 !"
    echo ""
    echo "Le problème vient peut-être de la configuration Nginx."
    echo "Vérifiez que Nginx utilise bien PHP $CURRENT_PHP_VERSION"
    exit 0
fi

log_warn "PHP $CURRENT_PHP_VERSION est trop ancien pour Baïkal 0.11.1"
echo ""

# Choix de la version à installer
echo "Quelle version de PHP voulez-vous installer ?"
echo "1) PHP 8.2 (Stable, recommandé)"
echo "2) PHP 8.3 (Dernière version)"
read -p "Votre choix [1]: " PHP_CHOICE
PHP_CHOICE=${PHP_CHOICE:-1}

if [ "$PHP_CHOICE" = "1" ]; then
    NEW_PHP_VERSION="8.2"
else
    NEW_PHP_VERSION="8.3"
fi

log_info "Installation de PHP $NEW_PHP_VERSION"
echo ""

# Confirmation
read -p "Voulez-vous continuer avec PHP $NEW_PHP_VERSION ? (o/n): " CONFIRM
if [ "$CONFIRM" != "o" ]; then
    log_info "Annulation"
    exit 0
fi

# Ajouter le repository Ondrej PHP
log_step "Ajout du repository PHP..."
apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:ondrej/php -y
apt-get update

log_info "Repository ajouté"

# Installer PHP et les extensions nécessaires
log_step "Installation de PHP $NEW_PHP_VERSION et extensions..."
apt-get install -y \
    php${NEW_PHP_VERSION} \
    php${NEW_PHP_VERSION}-fpm \
    php${NEW_PHP_VERSION}-cli \
    php${NEW_PHP_VERSION}-common \
    php${NEW_PHP_VERSION}-curl \
    php${NEW_PHP_VERSION}-mbstring \
    php${NEW_PHP_VERSION}-xml \
    php${NEW_PHP_VERSION}-zip \
    php${NEW_PHP_VERSION}-sqlite3 \
    php${NEW_PHP_VERSION}-mysql \
    php${NEW_PHP_VERSION}-gd \
    php${NEW_PHP_VERSION}-intl

log_info "PHP $NEW_PHP_VERSION installé"

# Configurer PHP-FPM
log_step "Configuration de PHP $NEW_PHP_VERSION..."

# Optimiser php.ini pour Baïkal
PHP_INI="/etc/php/${NEW_PHP_VERSION}/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    log_info "Optimisation de php.ini..."
    
    # Backup
    cp "$PHP_INI" "${PHP_INI}.backup"
    
    # Modifications
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    
    log_info "php.ini optimisé"
fi

# Mettre à jour la configuration Nginx
log_step "Mise à jour de la configuration Nginx..."

# Backup de la config Nginx
cp /etc/nginx/sites-available/baikal /etc/nginx/sites-available/baikal.backup.php.$(date +%Y%m%d_%H%M%S)

# Remplacer le socket PHP-FPM
OLD_SOCKET="unix:/var/run/php/php-fpm.sock"
NEW_SOCKET="unix:/var/run/php/php${NEW_PHP_VERSION}-fpm.sock"

sed -i "s|${OLD_SOCKET}|${NEW_SOCKET}|g" /etc/nginx/sites-available/baikal

# Vérifier le remplacement
if grep -q "php${NEW_PHP_VERSION}-fpm.sock" /etc/nginx/sites-available/baikal; then
    log_info "Configuration Nginx mise à jour pour PHP $NEW_PHP_VERSION"
else
    log_warn "Impossible de mettre à jour automatiquement la config Nginx"
    echo "Vous devrez modifier manuellement /etc/nginx/sites-available/baikal"
    echo "Remplacez: fastcgi_pass unix:/var/run/php/php-fpm.sock;"
    echo "Par: fastcgi_pass unix:/var/run/php/php${NEW_PHP_VERSION}-fpm.sock;"
fi

# Définir PHP CLI par défaut
log_step "Configuration de PHP $NEW_PHP_VERSION comme version par défaut..."
update-alternatives --set php /usr/bin/php${NEW_PHP_VERSION}

# Désactiver l'ancien PHP-FPM
if [ ! -z "$CURRENT_PHP_VERSION" ] && [ "$CURRENT_PHP_VERSION" != "$NEW_PHP_VERSION" ]; then
    log_info "Arrêt de PHP $CURRENT_PHP_VERSION..."
    systemctl stop php${CURRENT_PHP_VERSION}-fpm 2>/dev/null || true
    systemctl disable php${CURRENT_PHP_VERSION}-fpm 2>/dev/null || true
fi

# Activer et démarrer le nouveau PHP-FPM
log_step "Démarrage de PHP $NEW_PHP_VERSION-FPM..."
systemctl enable php${NEW_PHP_VERSION}-fpm
systemctl start php${NEW_PHP_VERSION}-fpm

# Vérifier le status
if systemctl is-active --quiet php${NEW_PHP_VERSION}-fpm; then
    log_info "PHP $NEW_PHP_VERSION-FPM démarré avec succès"
else
    log_error "PHP $NEW_PHP_VERSION-FPM n'a pas démarré"
    exit 1
fi

# Tester et redémarrer Nginx
log_step "Redémarrage de Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    systemctl restart nginx
    log_info "Nginx redémarré"
else
    log_error "Erreur dans la configuration Nginx"
    exit 1
fi

# Vérification finale
log_step "Vérification finale..."
echo ""

# Version PHP CLI
NEW_VERSION=$(php -v | head -1)
log_info "PHP CLI: $NEW_VERSION"

# Version PHP-FPM
if systemctl is-active --quiet php${NEW_PHP_VERSION}-fpm; then
    log_info "PHP-FPM: Actif"
else
    log_warn "PHP-FPM: Inactif"
fi

# Test Nginx
if systemctl is-active --quiet nginx; then
    log_info "Nginx: Actif"
else
    log_warn "Nginx: Inactif"
fi

# Rapport final
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}MISE À JOUR PHP TERMINÉE !${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Ancienne version: PHP $CURRENT_PHP_VERSION"
echo "Nouvelle version: PHP $NEW_PHP_VERSION"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "1. Testez l'accès à Baïkal:"
echo "   https://caldav.maison-oadf.ddns.net/"
echo ""
echo "2. Vérifiez qu'il n'y a plus d'erreur Composer"
echo ""
echo "3. Si problème, consultez les logs:"
echo "   - sudo tail -f /var/log/nginx/baikal_error.log"
echo "   - sudo journalctl -u php${NEW_PHP_VERSION}-fpm -f"
echo ""
echo "4. Anciennes versions PHP peuvent être supprimées:"
echo "   sudo apt remove php${CURRENT_PHP_VERSION}*"
echo ""

# Test HTTP
echo "Test de connexion..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    log_info "Test HTTP: OK (Code $HTTP_CODE)"
else
    log_warn "Test HTTP: Code $HTTP_CODE"
fi

echo ""
echo -e "${GREEN}✓ Installation terminée !${NC}"
