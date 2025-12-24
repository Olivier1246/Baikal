#!/bin/bash

################################################################################
# Script d'installation de Baïkal - Serveur CalDAV/CardDAV
# Pour Debian/Ubuntu
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration par défaut
BAIKAL_VERSION="0.9.5"
INSTALL_DIR="/var/www/baikal"
WEB_USER="www-data"
DB_TYPE="sqlite"  # ou "mysql"
DOMAIN_NAME=""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation de Baïkal ${BAIKAL_VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Demande de configuration
echo ""
read -p "Nom de domaine ou IP pour l'accès distant (ex: cal.example.com ou laissez vide pour localhost): " DOMAIN_NAME
read -p "Type de base de données (sqlite/mysql) [sqlite]: " DB_CHOICE
DB_TYPE=${DB_CHOICE:-sqlite}

if [ "$DB_TYPE" = "mysql" ]; then
    read -p "Nom de la base de données [baikal]: " DB_NAME
    DB_NAME=${DB_NAME:-baikal}
    read -p "Utilisateur MySQL [baikal]: " DB_USER
    DB_USER=${DB_USER:-baikal}
    read -sp "Mot de passe MySQL: " DB_PASS
    echo ""
fi

# Mise à jour du système
log_info "Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances PHP
log_info "Installation des dépendances PHP..."
apt-get install -y \
    php \
    php-fpm \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-sqlite3 \
    php-gd \
    unzip \
    wget \
    curl

# Installation de MySQL si nécessaire
if [ "$DB_TYPE" = "mysql" ]; then
    log_info "Installation de MySQL..."
    apt-get install -y mysql-server php-mysql
    
    # Configuration de la base de données
    log_info "Configuration de la base de données MySQL..."
    mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
fi

# Installation de Nginx
log_info "Installation de Nginx..."
apt-get install -y nginx

# Téléchargement de Baïkal
log_info "Téléchargement de Baïkal ${BAIKAL_VERSION}..."
cd /tmp
wget https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip

# Extraction et installation
log_info "Installation de Baïkal dans ${INSTALL_DIR}..."
unzip -q baikal-${BAIKAL_VERSION}.zip
rm -rf $INSTALL_DIR
mv baikal $INSTALL_DIR

# Configuration des permissions
log_info "Configuration des permissions..."
chown -R $WEB_USER:$WEB_USER $INSTALL_DIR
chmod -R 755 $INSTALL_DIR
chmod -R 770 $INSTALL_DIR/Specific
chmod -R 770 $INSTALL_DIR/config

# Création du fichier de configuration Nginx
log_info "Configuration de Nginx..."
if [ -z "$DOMAIN_NAME" ]; then
    SERVER_NAME="localhost"
    CONFIG_FILE="/etc/nginx/sites-available/baikal"
else
    SERVER_NAME="$DOMAIN_NAME"
    CONFIG_FILE="/etc/nginx/sites-available/baikal"
fi

cat > $CONFIG_FILE << 'NGINX_CONFIG'
server {
    listen 80;
    listen [::]:80;
    
    server_name SERVER_NAME_PLACEHOLDER;
    
    root /var/www/baikal/html;
    index index.php;
    
    # Logs
    access_log /var/log/nginx/baikal_access.log;
    error_log /var/log/nginx/baikal_error.log;
    
    # Redirection vers HTTPS (à décommenter après configuration SSL)
    # return 301 https://$server_name$request_uri;
    
    # Configuration CalDAV/CardDAV
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Sécurité - bloquer l'accès aux fichiers sensibles
    location ~ ^/(Specific|config) {
        deny all;
        return 403;
    }
    
    # PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Cache statique
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_CONFIG

sed -i "s/SERVER_NAME_PLACEHOLDER/$SERVER_NAME/g" $CONFIG_FILE

# Activation du site
ln -sf $CONFIG_FILE /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test de la configuration Nginx
nginx -t

# Redémarrage des services
log_info "Redémarrage des services..."
systemctl restart php*-fpm
systemctl restart nginx
systemctl enable nginx
systemctl enable php*-fpm

# Création du fichier d'informations
cat > /root/baikal_install_info.txt << EOF
========================================
Installation de Baïkal terminée !
========================================

Version: ${BAIKAL_VERSION}
Répertoire: ${INSTALL_DIR}
Base de données: ${DB_TYPE}

Accès Web:
- Local: http://localhost/
$([ ! -z "$DOMAIN_NAME" ] && echo "- Distant: http://$DOMAIN_NAME/")

Configuration initiale:
1. Ouvrez l'interface web
2. Suivez l'assistant de configuration
3. Configurez l'administrateur

$([ "$DB_TYPE" = "mysql" ] && cat << MYSQL_INFO
Configuration MySQL:
- Base: $DB_NAME
- Utilisateur: $DB_USER
- Mot de passe: [voir variables d'installation]
MYSQL_INFO
)

Prochaines étapes:
1. Configuration HTTPS avec: sudo ./setup_ssl.sh
2. Test de connexion avec un client CalDAV
3. Configuration de la sauvegarde: sudo ./setup_backup.sh

Clients compatibles:
- iOS: Paramètres > Comptes > CalDAV/CardDAV
- Android: DAVx5
- Thunderbird: Lightning + CardBook
- macOS: Calendrier/Contacts natifs

Logs:
- Nginx: /var/log/nginx/baikal_*.log
- PHP: /var/log/php*-fpm.log

EOF

cat /root/baikal_install_info.txt

log_info "Installation terminée !"
log_info "Informations sauvegardées dans: /root/baikal_install_info.txt"
log_warn "N'oubliez pas de configurer HTTPS pour l'accès distant !"

echo ""
read -p "Voulez-vous ouvrir l'interface web maintenant ? (y/n): " OPEN_WEB
if [ "$OPEN_WEB" = "y" ]; then
    if [ -z "$DOMAIN_NAME" ]; then
        log_info "Ouvrez http://localhost/ dans votre navigateur"
    else
        log_info "Ouvrez http://$DOMAIN_NAME/ dans votre navigateur"
    fi
fi
