#!/bin/bash
# Vérifier mises à jour disponibles

INSTALL_DIR="/var/www/baikal"
CURRENT=$(grep 'VERSION' "$INSTALL_DIR/Core/Frameworks/Baikal/Core.php" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "inconnue")
LATEST=$(curl -s https://api.github.com/repos/sabre-io/Baikal/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

echo "Version actuelle: $CURRENT"
echo "Dernière version: $LATEST"

if [ "$CURRENT" != "$LATEST" ] && [ ! -z "$LATEST" ]; then
    echo "✓ Mise à jour disponible!"
    echo "Pour mettre à jour: sudo ./maintenance/update.sh"
else
    echo "✓ Système à jour"
fi
