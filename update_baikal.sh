#!/bin/bash

################################################################################
# Script de mise à jour de Baïkal - VERSION FINALE CORRIGÉE
# Vérifie GitHub et propose toutes les versions disponibles
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GITHUB_REPO="sabre-io/Baikal"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases"
INSTALL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal/upgrade"
TEMP_DIR="/tmp/baikal_upgrade_$$"
WEB_USER="www-data"

# Fichiers temporaires
RELEASES_FILE="/tmp/baikal_releases_$$.txt"
TOTAL_FILE="/tmp/baikal_total_$$.txt"

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

# Nettoyage à la sortie
cleanup_temp() {
    rm -f "$RELEASES_FILE" "$TOTAL_FILE"
    rm -rf "$TEMP_DIR"
}
trap cleanup_temp EXIT

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
    local version="Inconnue"
    
    # Chercher dans plusieurs emplacements possibles
    if [ -f "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" ]; then
        version=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/Core/Frameworks/Baikal/WWWRoot/index.php" 2>/dev/null || echo "Inconnue")
    elif [ -f "$INSTALL_DIR/html/index.php" ]; then
        version=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/html/index.php" 2>/dev/null || echo "Inconnue")
    elif [ -f "$INSTALL_DIR/html/dav.php" ]; then
        version=$(grep -oP "VERSION\s*=\s*'\K[^']+" "$INSTALL_DIR/html/dav.php" 2>/dev/null || echo "Inconnue")
    fi
    
    echo "$version"
}

# Récupérer les releases depuis GitHub
fetch_releases() {
    log_step "Récupération des versions disponibles depuis GitHub..."
    
    # Vérifier curl et jq
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warn "jq n'est pas installé, installation..."
        apt-get update -qq
        apt-get install -y jq
    fi
    
    # Récupérer les releases et les sauvegarder dans un fichier
    curl -s "$GITHUB_API" | jq -r '.[] | "\(.tag_name)|\(.name)|\(.published_at)|\(.prerelease)"' > "$RELEASES_FILE"
    
    if [ ! -s "$RELEASES_FILE" ]; then
        log_error "Impossible de récupérer les releases depuis GitHub"
        exit 1
    fi
    
    # Compter le nombre de releases
    wc -l < "$RELEASES_FILE" > "$TOTAL_FILE"
    
    log_info "Releases récupérées avec succès"
}

# Afficher les versions disponibles
show_releases() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Versions disponibles${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_version=$(get_current_version)
    echo -e "Version actuelle : ${GREEN}$current_version${NC}"
    echo ""
    
    local index=1
    while IFS='|' read -r tag name date prerelease; do
        local formatted_date=$(date -d "$date" "+%d/%m/%Y" 2>/dev/null || echo "${date:0:10}")
        
        # Affichage coloré selon le type
        if [ "$prerelease" = "true" ]; then
            local status="${YELLOW}[PRE-RELEASE]${NC}"
        else
            local status="${GREEN}[STABLE]${NC}"
        fi
        
        # Marquer la version actuelle
        if [ "$tag" = "$current_version" ] || [ "$tag" = "v$current_version" ]; then
            local current_marker="${CYAN}[ACTUELLE]${NC}"
        else
            local current_marker=""
        fi
        
        printf "%2d. %-15s $status $current_marker\n" $index "$tag"
        printf "    Nom: %s\n" "$name"
        printf "    Date: %s\n" "$formatted_date"
        echo ""
        
        ((index++))
    done < "$RELEASES_FILE"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Sélectionner une version
select_version() {
    local total_releases=$(cat "$TOTAL_FILE")
    
    while true; do
        read -p "Choisissez une version à installer (1-$total_releases) ou 'q' pour quitter: " choice
        
        if [ "$choice" = "q" ]; then
            log_info "Annulation de la mise à jour"
            exit 0
        fi
        
        # Vérifier que c'est un nombre
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            log_error "Veuillez entrer un nombre valide"
            continue
        fi
        
        # Vérifier que c'est dans la plage
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "$total_releases" ]; then
            log_error "Veuillez choisir un nombre entre 1 et $total_releases"
            continue
        fi
        
        # Lire la ligne correspondante du fichier
        local line=$(sed -n "${choice}p" "$RELEASES_FILE")
        
        if [ -z "$line" ]; then
            log_error "Erreur lors de la lecture de la version sélectionnée"
            continue
        fi
        
        IFS='|' read -r tag name date prerelease <<< "$line"
        
        if [ -z "$tag" ]; then
            log_error "Erreur lors de l'extraction des informations de version"
            continue
        fi
        
        # Exporter les variables pour les autres fonctions
        export SELECTED_VERSION="$tag"
        export SELECTED_NAME="$name"
        export SELECTED_DATE=$(date -d "$date" "+%d/%m/%Y" 2>/dev/null || echo "${date:0:10}")
        export SELECTED_PRERELEASE="$prerelease"
        
        echo ""
        echo -e "${GREEN}Version sélectionnée:${NC}"
        echo "  Version: $SELECTED_VERSION"
        echo "  Nom: $SELECTED_NAME"
        echo "  Date: $SELECTED_DATE"
        
        if [ "$SELECTED_PRERELEASE" = "true" ]; then
            echo ""
            log_warn "Cette version est une PRE-RELEASE (non stable)"
            read -p "Voulez-vous vraiment continuer? (o/n): " confirm_pre
            if [ "$confirm_pre" != "o" ]; then
                log_info "Retour à la sélection..."
                echo ""
                continue
            fi
        fi
        
        break
    done
}

# Créer un backup avant mise à jour
create_backup() {
    log_step "Création d'un backup de sécurité..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_name="baikal_pre_upgrade_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "Sauvegarde de l'installation actuelle..."
    tar -czf "$backup_path.tar.gz" -C $(dirname "$INSTALL_DIR") $(basename "$INSTALL_DIR") 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local backup_size=$(du -sh "$backup_path.tar.gz" | cut -f1)
        log_info "Backup créé: $backup_path.tar.gz ($backup_size)"
        
        # Sauvegarder aussi la config Nginx
        if [ -f "/etc/nginx/sites-available/baikal" ]; then
            cp /etc/nginx/sites-available/baikal "$backup_path.nginx.conf"
            log_info "Configuration Nginx sauvegardée"
        fi
        
        echo "$backup_path.tar.gz" > /tmp/baikal_last_backup.txt
        export BACKUP_FILE="$backup_path.tar.gz"
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
    
    # Construire l'URL de téléchargement (sans le 'v' du tag)
    local version_number="${SELECTED_VERSION#v}"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${SELECTED_VERSION}/baikal-${version_number}.zip"
    
    log_info "URL: $download_url"
    echo ""
    
    # Télécharger avec barre de progression
    if wget --show-progress "$download_url" -O baikal.zip 2>&1; then
        log_info "Téléchargement terminé"
    else
        log_warn "Échec avec l'URL standard, tentative avec l'archive source..."
        
        # Essayer l'URL alternative
        download_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${SELECTED_VERSION}.zip"
        
        if wget --show-progress "$download_url" -O baikal.zip 2>&1; then
            log_info "Téléchargement terminé"
        else
            log_error "Impossible de télécharger la version"
            exit 1
        fi
    fi
}

# Installer la nouvelle version
install_version() {
    log_step "Installation de la nouvelle version..."
    
    # Arrêter les services
    log_info "Arrêt des services..."
    systemctl stop nginx
    systemctl stop php*-fpm
    
    # Extraire l'archive
    log_info "Extraction de l'archive..."
    cd "$TEMP_DIR"
    unzip -q baikal.zip
    
    # Trouver le répertoire extrait
    local extracted_dir=$(find . -maxdepth 1 -type d ! -name "." ! -name ".." | head -1)
    
    if [ -z "$extracted_dir" ]; then
        log_error "Impossible de trouver le répertoire extrait"
        exit 1
    fi
    
    log_info "Répertoire extrait: $extracted_dir"
    
    # Sauvegarder les données critiques
    log_info "Sauvegarde des données utilisateur..."
    cp -r "$INSTALL_DIR/Specific" "$TEMP_DIR/Specific_backup"
    cp -r "$INSTALL_DIR/config" "$TEMP_DIR/config_backup"
    
    # Supprimer l'ancienne installation (sauf données)
    log_info "Suppression de l'ancienne installation..."
    find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name 'Specific' ! -name 'config' -exec rm -rf {} +
    
    # Copier la nouvelle version
    log_info "Installation de la nouvelle version..."
    cp -r "$extracted_dir"/* "$INSTALL_DIR/"
    
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
    sleep 2
    systemctl start nginx
    
    # Vérifier que les services sont actifs
    sleep 2
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx n'a pas démarré correctement"
        log_error "Consultez les logs: journalctl -u nginx -n 50"
        read -p "Voulez-vous restaurer le backup? (o/n): " restore
        if [ "$restore" = "o" ]; then
            restore_backup
        fi
        exit 1
    fi
    
    if ! systemctl is-active --quiet php*-fpm; then
        log_error "PHP-FPM n'a pas démarré correctement"
        log_error "Consultez les logs: journalctl -u php*-fpm -n 50"
        read -p "Voulez-vous restaurer le backup? (o/n): " restore
        if [ "$restore" = "o" ]; then
            restore_backup
        fi
        exit 1
    fi
}

# Restaurer depuis le backup
restore_backup() {
    log_step "Restauration du backup..."
    
    if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE=$(cat /tmp/baikal_last_backup.txt 2>/dev/null)
    fi
    
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
    sleep 2
    local http_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null)
    
    if [ "$http_response" = "200" ] || [ "$http_response" = "302" ] || [ "$http_response" = "301" ]; then
        log_info "Serveur web répond correctement (HTTP $http_response)"
    else
        log_warn "Réponse HTTP inattendue: $http_response"
    fi
    
    # Vérifier la version installée
    local new_version=$(get_current_version)
    log_info "Version après mise à jour: $new_version"
    
    # Vérifier les permissions
    if [ -w "$INSTALL_DIR/Specific" ]; then
        log_info "Permissions correctes sur Specific/"
    else
        log_warn "Problème de permissions sur Specific/"
    fi
}

# Afficher le rapport final
show_report() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}MISE À JOUR TERMINÉE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Version installée: $SELECTED_VERSION"
    echo ""
    echo "Backup disponible dans:"
    echo "  $BACKUP_FILE"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "1. Testez l'interface web: http://votre-serveur/"
    echo "2. Vérifiez la synchronisation de vos appareils"
    echo "3. Consultez les logs en cas de problème:"
    echo "   - /var/log/nginx/baikal_error.log"
    echo "   - journalctl -u nginx -u php*-fpm"
    echo ""
}

# Programme principal
main() {
    show_header
    
    # Vérifications préliminaires
    check_installation
    
    # Afficher la version actuelle
    local current_version=$(get_current_version)
    echo -e "Version actuelle de Baïkal: ${GREEN}$current_version${NC}"
    echo ""
    
    # Récupérer les releases
    fetch_releases
    
    # Afficher les versions
    show_releases
    
    # Sélectionner la version
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
    read -p "Voulez-vous continuer? (o/n): " final_confirm
    
    if [ "$final_confirm" != "o" ]; then
        log_info "Annulation"
        exit 0
    fi
    
    # Exécuter la mise à jour
    create_backup
    download_version
    install_version
    verify_installation
    show_report
}

# Gestion des erreurs
trap 'log_error "Une erreur est survenue. Backup disponible dans: $BACKUP_FILE"' ERR

# Lancer le programme
main
