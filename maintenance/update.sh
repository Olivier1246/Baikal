#!/bin/bash
# Mise à jour Baïkal

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[ÉTAPE]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

INSTALL_DIR="/var/www/baikal"

# Vérifier que Baïkal est installé
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Baïkal n'est pas installé dans $INSTALL_DIR"
    exit 1
fi

# Détecter version actuelle - plusieurs méthodes
CURRENT=""

# Méthode 1: Fichier version dans config
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

# Méthode 4: Vérifier dans l'interface web
if [ -z "$CURRENT" ]; then
    CURRENT="inconnue"
    log_warn "Impossible de détecter la version actuelle automatiquement"
fi

log_info "Version actuelle: $CURRENT"
echo ""

# Vérifier dépendances
if ! command -v curl &> /dev/null; then
    log_error "curl n'est pas installé. Installation..."
    apt-get update -qq
    apt-get install -y curl
fi

if ! command -v jq &> /dev/null; then
    log_warn "jq n'est pas installé. Installation..."
    apt-get update -qq
    apt-get install -y jq
fi

if ! command -v wget &> /dev/null; then
    log_error "wget n'est pas installé. Installation..."
    apt-get install -y wget
fi

log_info "Récupération des versions disponibles depuis GitHub..."

# Récupérer les releases avec timeout et gestion d'erreur
RELEASES=$(curl -s --max-time 10 https://api.github.com/repos/sabre-io/Baikal/releases 2>/dev/null)

if [ -z "$RELEASES" ] || [ "$RELEASES" = "null" ]; then
    log_error "Impossible de récupérer les versions depuis GitHub"
    echo ""
    echo "Causes possibles:"
    echo "- Pas de connexion Internet"
    echo "- API GitHub inaccessible"
    echo "- Limite de requêtes API atteinte"
    echo ""
    echo "Essayez plus tard ou téléchargez manuellement depuis:"
    echo "https://github.com/sabre-io/Baikal/releases"
    exit 1
fi

# Parser les releases avec jq
RELEASES_LIST=$(echo "$RELEASES" | jq -r '.[] | "\(.tag_name)|\(.prerelease)|\(.published_at)"' 2>/dev/null)

if [ -z "$RELEASES_LIST" ]; then
    log_error "Erreur lors du parsing des versions"
    echo ""
    echo "Vérifiez manuellement les versions disponibles:"
    echo "https://github.com/sabre-io/Baikal/releases"
    exit 1
fi

echo ""
echo -e "${CYAN}Versions disponibles:${NC}"
echo "─────────────────────────────────────"

i=1
declare -A VERSION_MAP
while IFS='|' read -r version prerelease date; do
    if [ "$prerelease" = "true" ]; then
        STATUS="${YELLOW}(pre-release)${NC}"
    else
        STATUS="${GREEN}(stable)${NC}"
    fi
    
    # Formater la date
    RELEASE_DATE=$(date -d "$date" "+%d/%m/%Y" 2>/dev/null || echo "$date")
    
    echo -e "$i) $version $STATUS - $RELEASE_DATE"
    VERSION_MAP[$i]="$version"
    ((i++))
done <<< "$RELEASES_LIST"

echo "─────────────────────────────────────"
echo ""

# Sélection version
read -p "Choisir la version à installer [1]: " CHOICE
CHOICE=${CHOICE:-1}

if [ -z "${VERSION_MAP[$CHOICE]}" ]; then
    log_error "Choix invalide"
    exit 1
fi

VERSION="${VERSION_MAP[$CHOICE]}"

echo ""
log_info "Version sélectionnée: $VERSION"

# Confirmer
if [ "$CURRENT" != "inconnue" ]; then
    if [ "$VERSION" = "$CURRENT" ]; then
        log_warn "Cette version est déjà installée"
        read -p "Continuer quand même (réinstallation) ? (o/n): " CONFIRM
        [ "$CONFIRM" != "o" ] && exit 0
    fi
fi

read -p "Confirmer la mise à jour vers $VERSION ? (o/n) [o]: " CONFIRM
CONFIRM=${CONFIRM:-o}
[ "$CONFIRM" != "o" ] && exit 0

echo ""
log_step "Création d'un backup de sécurité..."
BACKUP_DIR="/var/backups/baikal"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf "$BACKUP_DIR/baikal_pre_update_${DATE}.tar.gz" -C "$INSTALL_DIR" Specific config 2>/dev/null || true
log_info "Backup créé: $BACKUP_DIR/baikal_pre_update_${DATE}.tar.gz"

log_step "Téléchargement de Baïkal $VERSION..."
cd /tmp
rm -rf baikal baikal-*.zip 2>/dev/null || true

DOWNLOAD_URL="https://github.com/sabre-io/Baikal/releases/download/${VERSION}/baikal-${VERSION}.zip"
log_info "URL: $DOWNLOAD_URL"

if ! wget -q --show-progress "$DOWNLOAD_URL"; then
    log_error "Échec du téléchargement"
    log_info "Essayez de télécharger manuellement depuis:"
    echo "  $DOWNLOAD_URL"
    exit 1
fi

log_step "Extraction..."
if ! unzip -q "baikal-${VERSION}.zip"; then
    log_error "Échec de l'extraction"
    exit 1
fi

log_step "Arrêt des services..."
systemctl stop nginx
systemctl stop php*-fpm

log_step "Sauvegarde des données utilisateur..."
cp -r "$INSTALL_DIR/Specific" /tmp/baikal_specific_backup
cp -r "$INSTALL_DIR/config" /tmp/baikal_config_backup

log_step "Installation de la nouvelle version..."
rm -rf "$INSTALL_DIR"
mv baikal "$INSTALL_DIR"

log_step "Restauration des données..."
cp -r /tmp/baikal_specific_backup/* "$INSTALL_DIR/Specific/"
cp -r /tmp/baikal_config_backup/* "$INSTALL_DIR/config/"

log_step "Configuration des permissions..."
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 770 "$INSTALL_DIR/Specific"
chmod -R 770 "$INSTALL_DIR/config"

if [ -f "$INSTALL_DIR/Specific/db/db.sqlite" ]; then
    chmod 660 "$INSTALL_DIR/Specific/db/db.sqlite"
fi

log_step "Redémarrage des services..."
systemctl start php*-fpm
systemctl start nginx

# Vérifier que tout fonctionne
sleep 2
if systemctl is-active --quiet nginx && systemctl is-active --quiet php*-fpm; then
    log_info "Services redémarrés avec succès"
else
    log_error "Problème avec les services!"
    log_warn "Restauration du backup..."
    
    systemctl stop nginx php*-fpm
    rm -rf "$INSTALL_DIR"
    tar -xzf "$BACKUP_DIR/baikal_pre_update_${DATE}.tar.gz" -C /
    systemctl start php*-fpm nginx
    
    log_error "Mise à jour annulée, backup restauré"
    exit 1
fi

echo ""
log_info "════════════════════════════════════════"
log_info "✓ Mise à jour terminée avec succès !"
log_info "════════════════════════════════════════"
echo ""
echo "Ancienne version: $CURRENT"
echo "Nouvelle version: $VERSION"
echo ""
echo "Backup disponible: $BACKUP_DIR/baikal_pre_update_${DATE}.tar.gz"
echo ""
echo "Prochaines étapes:"
echo "1. Testez l'interface web: http://localhost/"
echo "2. Vérifiez la synchronisation de vos clients"
echo "3. Si tout fonctionne, supprimez les anciens backups"
echo ""
