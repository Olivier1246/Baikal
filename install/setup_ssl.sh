#!/bin/bash

################################################################################
# Configuration SSL/HTTPS avec Let's Encrypt
# Projet: Baïkal Install Suite  
# Fichier: install/setup_ssl.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}Configuration SSL pour Baïkal${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"

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

log_info "Installation de Certbot..."
apt-get update -qq
apt-get install -y certbot python3-certbot-nginx

log_info "Obtention du certificat SSL..."
certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --email "$EMAIL" --redirect

log_info "Configuration du renouvellement automatique..."
systemctl enable certbot.timer
systemctl start certbot.timer

certbot renew --dry-run

cat > /root/baikal_ssl_info.txt << EOF
════════════════════════════════════════
Configuration SSL terminée !
════════════════════════════════════════

Domaine: $DOMAIN_NAME
Certificat: Let's Encrypt
Date: $(date)

Accès HTTPS: https://$DOMAIN_NAME/

Renouvellement:
- Automatique via certbot.timer
- Test: sudo certbot renew --dry-run

URLs CalDAV/CardDAV:
- CalDAV: https://$DOMAIN_NAME/.well-known/caldav
- CardDAV: https://$DOMAIN_NAME/.well-known/carddav

Vérification SSL:
https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN_NAME
EOF

cat /root/baikal_ssl_info.txt
log_info "Configuration SSL terminée avec succès !"

