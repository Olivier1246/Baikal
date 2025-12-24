#!/bin/bash

################################################################################
# Correction automatique des permissions CalDAV/CardDAV
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/var/www/baikal"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Correction des permissions CalDAV${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Arrêter les services
echo -e "${YELLOW}[1/5]${NC} Arrêt temporaire de Nginx..."
systemctl stop nginx
echo -e "${GREEN}✓ Nginx arrêté${NC}"
echo ""

# Corriger le propriétaire
echo -e "${YELLOW}[2/5]${NC} Correction du propriétaire..."
chown -R www-data:www-data "$INSTALL_DIR"
echo -e "${GREEN}✓ Propriétaire: www-data:www-data${NC}"
echo ""

# Corriger les permissions
echo -e "${YELLOW}[3/5]${NC} Correction des permissions..."

# Permissions de base
chmod 755 "$INSTALL_DIR"

# html/ en lecture
if [ -d "$INSTALL_DIR/html" ]; then
    chmod -R 755 "$INSTALL_DIR/html"
fi

# Specific/ en écriture
if [ -d "$INSTALL_DIR/Specific" ]; then
    chmod 770 "$INSTALL_DIR/Specific"
    chmod -R 770 "$INSTALL_DIR/Specific"/*
fi

# config/ en écriture
if [ -d "$INSTALL_DIR/config" ]; then
    chmod 770 "$INSTALL_DIR/config"
    chmod -R 770 "$INSTALL_DIR/config"/*
fi

# Base de données spécifiquement
if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    chmod 660 "$INSTALL_DIR/Specific/db/db.sqlite"
    echo "  db.sqlite: 660"
fi

# Répertoire db
if [ -d "$INSTALL_DIR/Specific/db" ]; then
    chmod 770 "$INSTALL_DIR/Specific/db"
    echo "  Specific/db: 770"
fi

echo -e "${GREEN}✓ Permissions corrigées${NC}"
echo ""

# Vérifier l'intégrité de la base
echo -e "${YELLOW}[4/5]${NC} Vérification de la base de données..."
if command -v sqlite3 &> /dev/null; then
    INTEGRITY=$(sudo -u www-data sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "PRAGMA integrity_check;" 2>&1)
    if [ "$INTEGRITY" = "ok" ]; then
        echo -e "${GREEN}✓ Base de données intègre${NC}"
    else
        echo -e "${YELLOW}⚠ Problème d'intégrité: $INTEGRITY${NC}"
    fi
    
    # Test d'écriture
    TEST=$(sudo -u www-data sqlite3 "$INSTALL_DIR/Specific/db/db.sqlite" "SELECT 1;" 2>&1)
    if [ "$TEST" = "1" ]; then
        echo -e "${GREEN}✓ Base accessible en écriture par www-data${NC}"
    else
        echo -e "${RED}✗ Base non accessible en écriture${NC}"
    fi
else
    echo -e "${YELLOW}⚠ sqlite3 non installé, impossible de vérifier${NC}"
fi
echo ""

# Redémarrer Nginx
echo -e "${YELLOW}[5/5]${NC} Redémarrage de Nginx..."
systemctl start nginx

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx redémarré${NC}"
else
    echo -e "${RED}✗ Échec du redémarrage de Nginx${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓✓✓ CORRECTION TERMINÉE ✓✓✓${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

# Résumé des permissions
echo "Résumé des permissions:"
echo "  $INSTALL_DIR/ : $(stat -c %a "$INSTALL_DIR") ($(stat -c %U:%G "$INSTALL_DIR"))"
echo "  Specific/     : $(stat -c %a "$INSTALL_DIR/Specific") ($(stat -c %U:%G "$INSTALL_DIR/Specific"))"
echo "  config/       : $(stat -c %a "$INSTALL_DIR/config") ($(stat -c %U:%G "$INSTALL_DIR/config"))"
echo "  db.sqlite     : $(stat -c %a "$INSTALL_DIR/Specific/db/db.sqlite") ($(stat -c %U:%G "$INSTALL_DIR/Specific/db/db.sqlite"))"
echo ""

echo "Testez maintenant dans Thunderbird:"
echo "  1. Créer un nouvel événement"
echo "  2. L'enregistrer"
echo "  3. Vérifier qu'il n'y a plus d'erreur"
echo ""
