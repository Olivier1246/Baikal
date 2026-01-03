#!/bin/bash

################################################################################
# Installation complète de Baïkal
# Projet: Baïkal Install Suite
# Fichier: install/baikal_install.sh
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BAIKAL_VERSION="0.11.1"
INSTALL_DIR="/var/www/baikal"
WEB_USER="www-data"

# Arguments
DOMAIN_NAME=""
DB_TYPE=""
DB_NAME=""
DB_USER=""
DB_PASS=""
NON_INTERACTIVE=false

# Fonctions
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

echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation de Baïkal ${BAIKAL_VERSION}${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

# Parsing des arguments en ligne de commande
while [ "$#" -gt 0 ]; do
    case "$1" in
        --domain) DOMAIN_NAME="$2"; shift 2;;
        --db) DB_TYPE="$2"; shift 2;;
        --db-name) DB_NAME="$2"; shift 2;;
        --db-user) DB_USER="$2"; shift 2;;
        --db-pass) DB_PASS="$2"; shift 2;;
        --non-interactive) NON_INTERACTIVE=true; shift 1;;
        *)
            log_error "Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Configuration interactive si les arguments ne sont pas passés
if [ "$NON_INTERACTIVE" = false ]; then
    if [ -z "$DOMAIN_NAME" ]; then
        read -p "Nom de domaine (ou vide pour localhost): " DOMAIN_NAME
    fi

    if [ -z "$DB_TYPE" ]; then
        read -p "Type de base de données (sqlite/mysql) [sqlite]: " DB_CHOICE
        DB_TYPE=${DB_CHOICE:-sqlite}
    fi

    if [ "$DB_TYPE" = "mysql" ]; then
        if [ -z "$DB_NAME" ]; then
            read -p "Nom de la base de données [baikal]: " DB_NAME
        fi

        if [ -z "$DB_USER" ]; then
            read -p "Utilisateur MySQL [baikal]: " DB_USER
        fi

        if [ -z "$DB_PASS" ]; then
            read -sp "Mot de passe MySQL: " DB_PASS
            echo ""
        fi
    fi
fi

# Valeurs par défaut pour les variables non définies
DB_TYPE=${DB_TYPE:-sqlite}
if [ "$DB_TYPE" = "mysql" ]; then
    DB_NAME=${DB_NAME:-baikal}
    DB_USER=${DB_USER:-baikal}
fi


# Validation pour l'installation non-interactive
if [ "$NON_INTERACTIVE" = true ] && [ "$DB_TYPE" = "mysql" ] && [ -z "$DB_PASS" ]; then
    log_error "En mode non-interactif, le mot de passe MySQL (--db-pass) est requis pour MySQL."
    exit 1
fi

# 1. Mise à jour système
log_step "Mise à jour du système..."
apt-get update -qq
apt-get upgrade -y -qq

# 2. Installation PHP
log_step "Installation de PHP et extensions..."
apt-get install -y \
    php \
    php-fpm \
    php-cli \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-sqlite3 \
    php-gd \
    php-intl \
    unzip \
    wget \
    curl \
    sqlite3

# 3. Installation MySQL si nécessaire
if [ "$DB_TYPE" = "mysql" ]; then
    log_step "Installation de MySQL..."
    apt-get install -y mysql-server php-mysql
    
    log_step "Configuration de la base de données MySQL..."
    mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
fi

# 4. Installation Nginx
log_step "Installation de Nginx..."
apt-get install -y nginx

# 5. Téléchargement Baïkal
log_step "Téléchargement de Baïkal ${BAIKAL_VERSION}..."
cd /tmp
rm -f baikal-${BAIKAL_VERSION}.zip
wget -q https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip

# 6. Installation Baïkal
log_step "Installation de Baïkal dans ${INSTALL_DIR}..."
rm -rf /tmp/baikal
unzip -q baikal-${BAIKAL_VERSION}.zip
rm -rf "$INSTALL_DIR"
mv baikal "$INSTALL_DIR"

# 7. Configuration permissions
log_step "Configuration des permissions..."
chown -R $WEB_USER:$WEB_USER "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 770 "$INSTALL_DIR/Specific"
chmod -R 770 "$INSTALL_DIR/config"

# 8. Configuration Nginx
log_step "Configuration de Nginx..."
if [ -z "$DOMAIN_NAME" ]; then
    SERVER_NAME="localhost"
else
    SERVER_NAME="$DOMAIN_NAME"
fi

cat > /etc/nginx/sites-available/baikal << NGINX_CONFIG
server {
    listen 80;
    listen [::]:80;
    
    server_name $SERVER_NAME;
    
    root /var/www/baikal/html;
    index index.php;
    
    # Logs
    access_log /var/log/nginx/baikal_access.log;
    error_log /var/log/nginx/baikal_error.log;
    
    # Taille max fichiers
    client_max_body_size 50M;
    
    # Configuration CalDAV/CardDAV
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # Sécurité - bloquer accès fichiers sensibles
    location ~ ^/(Specific|config) {
        deny all;
        return 403;
    }
    
    location ~ ^/\.ht {
        deny all;
        return 403;
    }
    
    # PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Cache statique
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Support WebDAV
    location ~ ^/.well-known/(caldav|carddav)$ {
        return 301 https://\$server_name/dav.php;
    }
}
NGINX_CONFIG

# Activation site
ln -sf /etc/nginx/sites-available/baikal /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test configuration
nginx -t

# 9. Redémarrage services
log_step "Redémarrage des services..."
systemctl restart php*-fpm
systemctl restart nginx
systemctl enable nginx
systemctl enable php*-fpm

# 10. Création fichier info
cat > /root/baikal_install_info.txt << EOF
════════════════════════════════════════
Installation de Baïkal terminée !
════════════════════════════════════════

Version: ${BAIKAL_VERSION}
Répertoire: ${INSTALL_DIR}
Base de données: ${DB_TYPE}
Date: $(date)

Accès Web:
- Local: http://localhost/
$([ ! -z "$DOMAIN_NAME" ] && echo "- Distant: http://$DOMAIN_NAME/")

Configuration initiale:
1. Ouvrez l'interface web
2. Suivez l'assistant de configuration
3. Créez le compte administrateur
4. Configurez la base de données

$([ "$DB_TYPE" = "mysql" ] && cat << MYSQL_INFO
Configuration MySQL:
- Base: $DB_NAME
- Utilisateur: $DB_USER
MYSQL_INFO
)

Prochaines étapes:
1. Configuration web: http://localhost/ ou http://$DOMAIN_NAME/
2. Configuration SSL (si distant): sudo ./install/setup_ssl.sh
3. Configuration backups: sudo ./maintenance/setup_backup.sh

Clients compatibles:
- iOS: Réglages > Comptes > CalDAV/CardDAV
- Android: DAVx⁵
- Thunderbird: Lightning + CardBook
- macOS: Calendrier/Contacts natifs

Fichiers importants:
- Installation: /var/www/baikal/
- Config Nginx: /etc/nginx/sites-available/baikal
- Logs: /var/log/nginx/baikal_*.log
- Données: /var/www/baikal/Specific/

Commandes utiles:
- Monitoring: sudo ./maintenance/monitor.sh
- Backup: sudo ./maintenance/backup.sh
- Logs: sudo tail -f /var/log/nginx/baikal_error.log

EOF

cat /root/baikal_install_info.txt

log_info ""
log_info "════════════════════════════════════════"
log_info "✓ Installation terminée avec succès !"
log_info "════════════════════════════════════════"
log_info ""
log_warn "⚠️  N'oubliez pas de:"
log_warn "1. Configurer l'interface web (voir ci-dessus)"
log_warn "2. Configurer HTTPS pour accès distant"
log_warn "3. Activer les backups automatiques"

echo ""
