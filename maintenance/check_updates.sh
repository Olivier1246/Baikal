#!/bin/bash
# Vérifier mises à jour disponibles

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="/var/www/baikal"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Vérification des mises à jour Baïkal${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Vérifier installation
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}✗ Baïkal n'est pas installé${NC}"
    exit 1
fi

# Détecter version actuelle
CURRENT=""

# Méthode 1: config/baikal.yaml
if [ -f "$INSTALL_DIR/config/baikal.yaml" ]; then
    CURRENT=$(grep -i "version" "$INSTALL_DIR/config/baikal.yaml" 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "")
fi

# Méthode 2: Core.php
if [ -z "$CURRENT" ] && [ -f "$INSTALL_DIR/Core/Frameworks/Baikal/Core.php" ]; then
    CURRENT=$(grep -i "VERSION" "$INSTALL_DIR/Core/Frameworks/Baikal/Core.php" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
fi

# Méthode 3: composer.json
if [ -z "$CURRENT" ] && [ -f "$INSTALL_DIR/composer.json" ]; then
    CURRENT=$(grep '"version"' "$INSTALL_DIR/composer.json" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "")
fi

# Si pas de version détectée, essayer autrement
if [ -z "$CURRENT" ]; then
    # Chercher dans tous les fichiers PHP
    CURRENT=$(grep -r "VERSION.*=.*['\"]" "$INSTALL_DIR" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
fi

if [ -z "$CURRENT" ]; then
    CURRENT="inconnue"
    echo -e "${YELLOW}⚠ Version actuelle: $CURRENT${NC}"
    echo "  (Impossible de détecter automatiquement)"
else
    echo -e "${GREEN}✓ Version actuelle: $CURRENT${NC}"
fi

echo ""

# Vérifier connexion Internet
if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "${RED}✗ Pas de connexion Internet${NC}"
    exit 1
fi

# Installer jq si nécessaire
if ! command -v jq &> /dev/null; then
    echo "Installation de jq..."
    apt-get update -qq && apt-get install -y jq &> /dev/null
fi

# Récupérer dernière version stable
echo "Vérification sur GitHub..."
LATEST=$(curl -s --max-time 10 https://api.github.com/repos/sabre-io/Baikal/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null)

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    echo -e "${RED}✗ Impossible de contacter GitHub${NC}"
    echo ""
    echo "Vérifiez manuellement sur:"
    echo "https://github.com/sabre-io/Baikal/releases"
    exit 1
fi

echo -e "${GREEN}✓ Dernière version stable: $LATEST${NC}"
echo ""

# Comparer versions
if [ "$CURRENT" = "$LATEST" ]; then
    echo -e "${GREEN}✓ Système à jour !${NC}"
    echo ""
elif [ "$CURRENT" = "inconnue" ]; then
    echo -e "${YELLOW}⚠ Impossible de comparer les versions${NC}"
    echo ""
    echo "Pour mettre à jour vers $LATEST:"
    echo "  sudo ./maintenance/update.sh"
    echo ""
else
    # Comparer numériquement
    CURRENT_NUM=$(echo "$CURRENT" | tr -d '.')
    LATEST_NUM=$(echo "$LATEST" | tr -d '.')
    
    if [ "$LATEST_NUM" -gt "$CURRENT_NUM" ] 2>/dev/null; then
        echo -e "${YELLOW}✓ Mise à jour disponible !${NC}"
        echo ""
        echo "  $CURRENT → $LATEST"
        echo ""
        echo "Pour mettre à jour:"
        echo -e "  ${BLUE}sudo ./maintenance/update.sh${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Version actuelle est la plus récente${NC}"
        echo ""
    fi
fi

# Afficher autres versions disponibles
echo "Pour voir toutes les versions:"
echo "  curl -s https://api.github.com/repos/sabre-io/Baikal/releases | jq -r '.[].tag_name'"
echo ""
