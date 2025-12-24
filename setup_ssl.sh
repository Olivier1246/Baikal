#!/bin/bash

################################################################################
# Configuration SSL pour Baïkal avec Let's Encrypt
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Configuration SSL pour Baïkal${NC}"
echo -e "${GREEN}========================================${NC}"

# Demande du nom de domaine
read -p "Nom de domaine (ex: cal.example.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    log_error "Le nom de domaine est obligatoire"
    exit 1
fi

read -p "Email pour Let's Encrypt: " EMAIL
if [ -z "$EMAIL" ]; then
    log_error "L'email est obligatoire"
    exit 1
fi

# Installation de Certbot
log_info "Installation de Certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Obtention du certificat
log_info "Obtention du certificat SSL..."
certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $EMAIL --redirect

# Configuration Nginx avec HTTPS
log_info "Configuration Nginx avec HTTPS..."
cat > /etc/nginx/sites-available/baikal << 'NGINX_SSL_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Redirection HTTP vers HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name DOMAIN_PLACEHOLDER;
    
    root /var/www/baikal/html;
    index index.php;
    
    # Logs
    access_log /var/log/nginx/baikal_access.log;
    error_log /var/log/nginx/baikal_error.log;
    
    # Certificats SSL (gérés par Certbot)
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Sécurité SSL renforcée
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    
    # Headers de sécurité
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Taille maximale des fichiers
    client_max_body_size 50M;
    
    # Configuration CalDAV/CardDAV
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Sécurité - bloquer l'accès aux fichiers sensibles
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
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Timeouts augmentés pour les grosses synchronisations
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }
    
    # Cache statique
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Support WebDAV
    location ~ ^/.well-known/(caldav|carddav)$ {
        return 301 https://$server_name/dav.php;
    }
}
NGINX_SSL_CONFIG

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN_NAME/g" /etc/nginx/sites-available/baikal

# Test et redémarrage Nginx
log_info "Test de la configuration Nginx..."
nginx -t

log_info "Redémarrage de Nginx..."
systemctl restart nginx

# Configuration du renouvellement automatique
log_info "Configuration du renouvellement automatique..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Test du renouvellement
certbot renew --dry-run

# Informations
cat > /root/baikal_ssl_info.txt << EOF
========================================
Configuration SSL terminée !
========================================

Domaine: $DOMAIN_NAME
Certificat: Let's Encrypt

Accès HTTPS:
- https://$DOMAIN_NAME/

Renouvellement automatique:
- Configuré via systemd timer
- Test: sudo certbot renew --dry-run

Configuration CalDAV/CardDAV:
- Serveur: $DOMAIN_NAME
- Port: 443 (HTTPS)
- Chemin principal: /dav.php
- Chemin calendrier: /dav.php/calendars/[utilisateur]/[calendrier]
- Chemin contacts: /dav.php/addressbooks/[utilisateur]/[carnet]

URLs de découverte automatique:
- CalDAV: https://$DOMAIN_NAME/.well-known/caldav
- CardDAV: https://$DOMAIN_NAME/.well-known/carddav

Vérification du certificat:
- https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN_NAME

EOF

cat /root/baikal_ssl_info.txt

log_info "Configuration SSL terminée avec succès !"
log_info "Informations sauvegardées dans: /root/baikal_ssl_info.txt"
log_warn "Testez l'accès à https://$DOMAIN_NAME/"
