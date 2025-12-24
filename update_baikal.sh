#!/bin/bash

################################################################################
# Script de mise à jour de Baïkal
# Vérifie GitHub et propose toutes les versions disponibles
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
GITHUB_REPO="sabre-io/Baikal"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases"
INSTALL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal/upgrade"
TEMP_DIR="/tmp/baikal_upgrade"
WEB_USER="www-data"

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

# Fonctions d'affichage
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

# Fonction pour afficher le header
show_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         MISE À JOUR DE BAÏKAL                            ║
║         Version automatique depuis GitHub                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Vérifier si Baïkal est installé
check_installation() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Baïkal n'est pas installé dans $INSTALL_DIR"
        exit 1
    fi
    
    if [ ! -d "$INSTALL_DIR/Specific" ]; then
        log_error "Répertoire de données Baïkal introuvable"
        exit 1
    fi
}

# Obtenir la version actuelle
get_current_version() {
    if [ -f "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" ]; then
        CURRENT_VERSION=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" 2>/dev/null || echo "Inconnue")
    elif [ -f "$INSTALL_DIR/html/index.php" ]; then
        CURRENT_VERSION=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/html/index.php" 2>/dev/null || echo "Inconnue")
    else
        CURRENT_VERSION="Inconnue"
    fi
    
    echo "$CURRENT_VERSION"
}

# Récupérer les releases depuis GitHub
fetch_releases() {
    log_step "Récupération des versions disponibles depuis GitHub..."
    
    # Vérifier curl
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé"
        exit 1
    fi
    
    # Vérifier jq
    if ! command -v jq &> /dev/null; then
        log_warn "jq n'est pas installé, installation..."
        apt-get update -qq
        apt-get install -y jq
    fi
    
    # Récupérer les releases
    RELEASES_JSON=$(curl -s "$GITHUB_API")
    
    if [ -z "$RELEASES_JSON" ]; then
        log_error "Impossible de récupérer les releases depuis GitHub"
        exit 1
    fi
    
    # Vérifier si on a des données valides
    if echo "$RELEASES_JSON" | jq -e . >/dev/null 2>&1; then
        log_info "Releases récupérées avec succès"
    else
        log_error "Erreur lors de la récupération des releases"
        echo "$RELEASES_JSON"
        exit 1
    fi
}

# Afficher les versions disponibles
show_releases() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Versions disponibles${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    CURRENT_VERSION=$(get_current_version)
    echo -e "Version actuelle : ${GREEN}$CURRENT_VERSION${NC}"
    echo ""
    
    # Extraire et formater les releases
    RELEASES=$(echo "$RELEASES_JSON" | jq -r '.[] | "\(.tag_name)|\(.name)|\(.published_at)|\(.prerelease)|\(.zipball_url)"')
    
    if [ -z "$RELEASES" ]; then
        log_error "Aucune release trouvée"
        exit 1
    fi
    
    # Créer des tableaux pour stocker les infos
    declare -a VERSIONS
    declare -a NAMES
    declare -a DATES
    declare -a PRERELEASES
    declare -a URLS
    
    INDEX=1
    while IFS='|' read -r tag name date prerelease url; do
        VERSIONS[$INDEX]=$tag
        NAMES[$INDEX]=$name
        DATES[$INDEX]=$(date -d "$date" "+%d/%m/%Y" 2>/dev/null || echo "$date")
        PRERELEASES[$INDEX]=$prerelease
        URLS[$INDEX]=$url
        
        # Affichage coloré selon le type
        if [ "$prerelease" = "true" ]; then
            STATUS="${YELLOW}[PRE-RELEASE]${NC}"
        else
            STATUS="${GREEN}[STABLE]${NC}"
        fi
        
        # Marquer la version actuelle
        if [ "$tag" = "$CURRENT_VERSION" ] || [ "$tag" = "v$CURRENT_VERSION" ]; then
            CURRENT="${CYAN}[ACTUELLE]${NC}"
        else
            CURRENT=""
        fi
        
        printf "%2d. %-15s $STATUS $CURRENT\n" $INDEX "${VERSIONS[$INDEX]}"
        printf "    Nom: %s\n" "${NAMES[$INDEX]}"
        printf "    Date: %s\n" "${DATES[$INDEX]}"
        echo ""
        
        ((INDEX++))
    done <<< "$RELEASES"
    
    TOTAL_RELEASES=$((INDEX - 1))
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Sélectionner une version
select_version() {
    while true; do
        read -p "Choisissez une version à installer (1-$TOTAL_RELEASES) ou 'q' pour quitter: " CHOICE
        
        if [ "$CHOICE" = "q" ]; then
            log_info "Annulation de la mise à jour"
            exit 0
        fi
        
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$TOTAL_RELEASES" ]; then
            SELECTED_VERSION="${VERSIONS[$CHOICE]}"
            SELECTED_NAME="${NAMES[$CHOICE]}"
            SELECTED_DATE="${DATES[$CHOICE]}"
            SELECTED_PRERELEASE="${PRERELEASES[$CHOICE]}"
            SELECTED_URL="${URLS[$CHOICE]}"
            break
        else
            log_error "Choix invalide"
        fi
    done
    
    echo ""
    echo -e "${GREEN}Version sélectionnée:${NC}"
    echo "  Version: $SELECTED_VERSION"
    echo "  Nom: $SELECTED_NAME"
    echo "  Date: $SELECTED_DATE"
    
    if [ "$SELECTED_PRERELEASE" = "true" ]; then
        echo ""
        log_warn "Cette version est une PRE-RELEASE (non stable)"
        read -p "Voulez-vous vraiment continuer? (o/n): " CONFIRM_PRE
        if [ "$CONFIRM_PRE" != "o" ]; then
            log_info "Annulation"
            exit 0
        fi
    fi
}

# Créer un backup avant mise à jour
create_backup() {
    log_step "Création d'un backup de sécurité..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_NAME="baikal_pre_upgrade_$(date +%Y%m%d_%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log_info "Sauvegarde de l'installation actuelle..."
    tar -czf "$BACKUP_PATH.tar.gz" -C $(dirname "$INSTALL_DIR") $(basename "$INSTALL_DIR") 2>/dev/null
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH.tar.gz" | cut -f1)
        log_info "Backup créé: $BACKUP_PATH.tar.gz ($BACKUP_SIZE)"
        
        # Sauvegarder aussi la config Nginx
        if [ -f "/etc/nginx/sites-available/baikal" ]; then
            cp /etc/nginx/sites-available/baikal "$BACKUP_PATH.nginx.conf"
            log_info "Configuration Nginx sauvegardée"
        fi
        
        echo "$BACKUP_PATH.tar.gz" > /tmp/baikal_last_backup.txt
    else
        log_error "Échec de la création du backup"
        exit 1
    fi
}

# Télécharger la nouvelle version
download_version() {
    log_step "Téléchargement de Baïkal $SELECTED_VERSION..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Construire l'URL de téléchargement
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${SELECTED_VERSION}/baikal-${SELECTED_VERSION#v}.zip"
    
    log_info "URL: $DOWNLOAD_URL"
    
    # Télécharger
    wget -q --show-progress "$DOWNLOAD_URL" -O baikal.zip
    
    if [ $? -ne 0 ]; then
        log_error "Échec du téléchargement"
        log_info "Tentative avec l'URL alternative..."
        
        # Essayer avec zipball_url
        wget -q --show-progress "$SELECTED_URL" -O baikal.zip
        
        if [ $? -ne 0 ]; then
            log_error "Impossible de télécharger la version"
            exit 1
        fi
    fi
    
    log_info "Téléchargement terminé"
}

# Installer la nouvelle version
install_version() {
    log_step "Installation de la nouvelle version..."
    
    # Arrêter les services
    log_info "Arrêt des services..."
    systemctl stop nginx php*-fpm
    
    # Extraire l'archive
    log_info "Extraction de l'archive..."
    cd "$TEMP_DIR"
    unzip -q baikal.zip
    
    # Trouver le répertoire extrait
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "baikal*" -o -name "*Baikal*" | head -1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        # Peut-être que les fichiers sont directement dans le zip
        EXTRACTED_DIR="."
    fi
    
    # Sauvegarder les données critiques
    log_info "Sauvegarde des données utilisateur..."
    cp -r "$INSTALL_DIR/Specific" "$TEMP_DIR/Specific_backup"
    cp -r "$INSTALL_DIR/config" "$TEMP_DIR/config_backup"
    
    # Supprimer l'ancienne installation (sauf données)
    log_info "Suppression de l'ancienne installation..."
    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name 'Specific' ! -name 'config' -exec rm -rf {} +
    
    # Copier la nouvelle version
    log_info "Installation de la nouvelle version..."
    if [ "$EXTRACTED_DIR" = "." ]; then
        cp -r * "$INSTALL_DIR/"
    else
        cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR/"
    fi
    
    # Restaurer les données
    log_info "Restauration des données utilisateur..."
    rm -rf "$INSTALL_DIR/Specific"
    rm -rf "$INSTALL_DIR/config"
    cp -r "$TEMP_DIR/Specific_backup" "$INSTALL_DIR/Specific"
    cp -r "$TEMP_DIR/config_backup" "$INSTALL_DIR/config"
    
    # Corriger les permissions
    log_info "Configuration des permissions..."
    chown -R $WEB_USER:$WEB_USER "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    chmod -R 770 "$INSTALL_DIR/Specific"
    chmod -R 770 "$INSTALL_DIR/config"
    
    # Redémarrer les services
    log_info "Redémarrage des services..."
    systemctl start php*-fpm
    systemctl start nginx
    
    # Vérifier que les services sont actifs
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx n'a pas démarré correctement"
        read -p "Voulez-vous restaurer le backup? (o/n): " RESTORE
        if [ "$RESTORE" = "o" ]; then
            restore_backup
        fi
        exit 1
    fi
    
    if ! systemctl is-active --quiet php*-fpm; then
        log_error "PHP-FPM n'a pas démarré correctement"
        read -p "Voulez-vous restaurer le backup? (o/n): " RESTORE
        if [ "$RESTORE" = "o" ]; then
            restore_backup
        fi
        exit 1
    fi
}

# Restaurer depuis le backup
restore_backup() {
    log_step "Restauration du backup..."
    
    BACKUP_FILE=$(cat /tmp/baikal_last_backup.txt 2>/dev/null)
    
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        log_error "Fichier de backup introuvable"
        return 1
    fi
    
    # Arrêter les services
    systemctl stop nginx php*-fpm
    
    # Restaurer
    rm -rf "$INSTALL_DIR"
    tar -xzf "$BACKUP_FILE" -C $(dirname "$INSTALL_DIR")
    
    # Corriger les permissions
    chown -R $WEB_USER:$WEB_USER "$INSTALL_DIR"
    
    # Redémarrer
    systemctl start php*-fpm nginx
    
    log_info "Backup restauré avec succès"
}

# Vérifier l'installation
verify_installation() {
    log_step "Vérification de l'installation..."
    
    # Test HTTP local
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null)
    
    if [ "$HTTP_RESPONSE" = "200" ] || [ "$HTTP_RESPONSE" = "302" ]; then
        log_info "Serveur web répond correctement (HTTP $HTTP_RESPONSE)"
    else
        log_warn "Réponse HTTP inattendue: $HTTP_RESPONSE"
    fi
    
    # Vérifier la version installée
    NEW_VERSION=$(get_current_version)
    log_info "Nouvelle version installée: $NEW_VERSION"
    
    # Vérifier les permissions
    if [ -w "$INSTALL_DIR/Specific" ]; then
        log_info "Permissions correctes sur Specific/"
    else
        log_warn "Problème de permissions sur Specific/"
    fi
    
    if [ -w "$INSTALL_DIR/config" ]; then
        log_info "Permissions correctes sur config/"
    else
        log_warn "Problème de permissions sur config/"
    fi
}

# Nettoyer les fichiers temporaires
cleanup() {
    log_step "Nettoyage..."
    rm -rf "$TEMP_DIR"
    log_info "Fichiers temporaires supprimés"
}

# Afficher le rapport final
show_report() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}MISE À JOUR TERMINÉE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Version précédente: $CURRENT_VERSION"
    echo "Nouvelle version: $SELECTED_VERSION"
    echo ""
    echo "Backup disponible dans:"
    echo "  $(cat /tmp/baikal_last_backup.txt 2>/dev/null)"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "1. Testez l'interface web: http://votre-serveur/"
    echo "2. Vérifiez la synchronisation de vos appareils"
    echo "3. Consultez les logs en cas de problème:"
    echo "   - /var/log/nginx/baikal_error.log"
    echo "   - journalctl -u nginx -u php*-fpm"
    echo ""
    echo "En cas de problème, restaurez le backup:"
    echo "  sudo tar -xzf $(cat /tmp/baikal_last_backup.txt 2>/dev/null) -C $(dirname "$INSTALL_DIR")"
    echo ""
}

# Programme principal
main() {
    show_header
    
    # Vérifications préliminaires
    check_installation
    
    # Afficher la version actuelle
    CURRENT_VERSION=$(get_current_version)
    echo -e "Version actuelle de Baïkal: ${GREEN}$CURRENT_VERSION${NC}"
    echo ""
    
    # Récupérer les releases
    fetch_releases
    
    # Afficher et sélectionner
    show_releases
    select_version
    
    # Confirmation finale
    echo ""
    echo -e "${YELLOW}⚠ ATTENTION ⚠${NC}"
    echo "Cette opération va:"
    echo "  1. Créer un backup complet"
    echo "  2. Arrêter Nginx et PHP-FPM"
    echo "  3. Installer Baïkal $SELECTED_VERSION"
    echo "  4. Redémarrer les services"
    echo ""
    read -p "Voulez-vous continuer? (o/n): " FINAL_CONFIRM
    
    if [ "$FINAL_CONFIRM" != "o" ]; then
        log_info "Annulation"
        exit 0
    fi
    
    # Exécuter la mise à jour
    create_backup
    download_version
    install_version
    verify_installation
    cleanup
    show_report
}

# Gestion des erreurs
trap 'log_error "Une erreur est survenue. Backup disponible dans: $(cat /tmp/baikal_last_backup.txt 2>/dev/null)"' ERR

# Lancer le programme
main
