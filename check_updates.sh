#!/bin/bash

################################################################################
# Vérification rapide des mises à jour Baïkal disponibles
################################################################################

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GITHUB_REPO="sabre-io/Baikal"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
INSTALL_DIR="/var/www/baikal"

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Vérification des mises à jour Baïkal${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Obtenir la version actuelle
if [ -f "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" ]; then
    CURRENT_VERSION=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" 2>/dev/null || echo "Inconnue")
elif [ -f "$INSTALL_DIR/html/index.php" ]; then
    CURRENT_VERSION=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/html/index.php" 2>/dev/null || echo "Inconnue")
else
    CURRENT_VERSION="Inconnue"
fi

echo "Version actuelle: ${GREEN}$CURRENT_VERSION${NC}"

# Récupérer la dernière version stable
echo -e "\nVérification de la dernière version..."

if command -v curl &> /dev/null; then
    LATEST_RELEASE=$(curl -s "$GITHUB_API")
    
    if [ ! -z "$LATEST_RELEASE" ]; then
        if command -v jq &> /dev/null; then
            LATEST_VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
            LATEST_NAME=$(echo "$LATEST_RELEASE" | jq -r '.name')
            LATEST_DATE=$(echo "$LATEST_RELEASE" | jq -r '.published_at' | cut -d'T' -f1)
            
            echo "Dernière version stable: ${GREEN}$LATEST_VERSION${NC}"
            echo "Nom: $LATEST_NAME"
            echo "Date de sortie: $LATEST_DATE"
            
            # Comparer les versions
            if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] || [ "v$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
                echo ""
                echo -e "${GREEN}✓ Votre installation est à jour !${NC}"
            else
                echo ""
                echo -e "${YELLOW}⚠ Une mise à jour est disponible !${NC}"
                echo ""
                echo "Pour mettre à jour:"
                echo "  sudo ./update_baikal.sh"
            fi
        else
            echo "Installation de jq requise pour afficher les détails"
            echo "Installez avec: sudo apt install jq"
        fi
    else
        echo -e "${YELLOW}Impossible de vérifier les mises à jour${NC}"
    fi
else
    echo "curl n'est pas installé"
    echo "Installez avec: sudo apt install curl"
fi

echo ""
echo "Plus d'infos: https://github.com/${GITHUB_REPO}/releases"
echo ""
