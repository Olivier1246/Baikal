#!/bin/bash
# Mise à jour Baïkal

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

INSTALL_DIR="/var/www/baikal"
CURRENT=$(grep 'VERSION' "$INSTALL_DIR/Core/Frameworks/Baikal/Core.php" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "inconnue")

log_info "Version actuelle: $CURRENT"
log_info "Récupération des versions disponibles..."

RELEASES=$(curl -s https://api.github.com/repos/sabre-io/Baikal/releases | jq -r '.[] | "\(.tag_name)|\(.prerelease)"' 2>/dev/null)

if [ -z "$RELEASES" ]; then
    echo "Erreur: Impossible de récupérer les versions"
    exit 1
fi

echo ""
echo "Versions disponibles:"
i=1
while IFS='|' read -r version prerelease; do
    [ "$prerelease" = "true" ] && STATUS="(pre-release)" || STATUS="(stable)"
    echo "$i) $version $STATUS"
    ((i++))
done <<< "$RELEASES"

read -p "Choisir version à installer [1]: " CHOICE
CHOICE=${CHOICE:-1}

VERSION=$(echo "$RELEASES" | sed -n "${CHOICE}p" | cut -d'|' -f1)

log_step "Création backup..."
./backup.sh

log_step "Téléchargement Baïkal $VERSION..."
cd /tmp
wget -q "https://github.com/sabre-io/Baikal/releases/download/${VERSION}/baikal-${VERSION}.zip"
unzip -q "baikal-${VERSION}.zip"

log_step "Installation..."
systemctl stop nginx php*-fpm

cp -r "$INSTALL_DIR/Specific" /tmp/baikal_specific_backup
cp -r "$INSTALL_DIR/config" /tmp/baikal_config_backup

rm -rf "$INSTALL_DIR"
mv baikal "$INSTALL_DIR"

cp -r /tmp/baikal_specific_backup/* "$INSTALL_DIR/Specific/"
cp -r /tmp/baikal_config_backup/* "$INSTALL_DIR/config/"

chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 770 "$INSTALL_DIR/Specific"
chmod -R 770 "$INSTALL_DIR/config"

systemctl start php*-fpm nginx

log_info "Mise à jour vers $VERSION terminée!"
