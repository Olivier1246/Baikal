#!/bin/bash

################################################################################
# Script de démarrage - Menu interactif principal
# Projet: Baïkal Install Suite
# Fichier: install/start.sh
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Fonctions d'affichage
show_header() {
    clear
    echo -e "${CYAN}"
    echo "+---------------------------------------------------------------+"
    echo "|                                                               |"
    echo "|     ____        ______            __                          |"
    echo "|    / __ )____ _/  _/ /______ _   / /                          |"
    echo "|   / __  / __ \`/_ // //_/ __ \`/  / /                           |"
    echo "|  / /_/ / /_/ /_ |/ ,< / /_/ /  / /                            |"
    echo "| /_____/\__,_/___/_/|_|\__,_/  /_/                             |"
    echo "|                                                               |"
    echo "|           Serveur CalDAV/CardDAV auto-heberge                 |"
    echo "|                    Installation Suite v2.0                    |"
    echo "|                                                               |"
    echo "+---------------------------------------------------------------+"
    echo -e "${NC}"
}

# Vérification root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Erreur: Ce script doit être exécuté avec sudo${NC}"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

# Menu principal
show_menu() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}        MENU PRINCIPAL${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "1. Vérifier les prérequis système"
    echo "2. Installation complète (recommandé) ⭐"
    echo "3. Installation personnalisée"
    echo "4. Configuration SSL/HTTPS"
    echo "5. Configuration des backups automatiques"
    echo "6. Monitoring du système"
    echo "7. Mise à jour Baïkal"
    echo "8. Afficher la documentation"
    echo "9. Quitter"
    echo ""
}

# Option 1: Vérifier prérequis
option_check_prereqs() {
    echo ""
    echo -e "${GREEN}=== Vérification des prérequis ===${NC}"
    echo ""
    "$SCRIPT_DIR/check_prereqs.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 2: Installation complète
option_full_install() {
    clear
    show_header
    echo -e "${GREEN}=== Installation complète de Baïkal ===${NC}"
    echo ""
    echo "Cette installation va:"
    echo "✓ Installer toutes les dépendances (Nginx, PHP, etc.)"
    echo "✓ Télécharger et configurer Baïkal"
    echo "✓ Configurer les permissions"
    echo "✓ Créer la base de données SQLite"
    echo ""
    read -p "Continuer ? (o/n) [o]: " confirm
    confirm=${confirm:-o}
    
    if [ "$confirm" = "o" ]; then
        echo ""
        "$SCRIPT_DIR/baikal_install.sh" --db sqlite --non-interactive
        
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Installation terminée !${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo "📌 Prochaines étapes:"
        echo "1. Configuration web: Ouvrez http://localhost/ dans votre navigateur"
        echo "2. Si accès distant souhaité: Lancez l'option 4 (Configuration SSL)"
        echo "3. Configuration backups: Option 5"
        echo ""
    fi
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 3: Installation personnalisée
option_custom_install() {
    clear
    show_header
    echo -e "${GREEN}=== Installation personnalisée ===${NC}"
    echo ""

    # Arguments pour baikal_install.sh
    INSTALL_ARGS=()

    # Type d'installation
    echo "Type d'installation:"
    echo "1. Local uniquement (localhost)"
    echo "2. Distant (avec nom de domaine)"
    read -p "Votre choix [1]: " install_type
    install_type=${install_type:-1}

    if [ "$install_type" = "2" ]; then
        read -p "Entrez votre nom de domaine: " domain_name
        INSTALL_ARGS+=(--domain "$domain_name")
    fi
    
    # Base de données
    echo ""
    echo "Base de données:"
    echo "1. SQLite (recommandé pour usage personnel)"
    echo "2. MySQL (pour usage intensif)"
    read -p "Votre choix [1]: " db_choice
    db_choice=${db_choice:-1}

    if [ "$db_choice" = "1" ]; then
        INSTALL_ARGS+=(--db "sqlite")
        DB_TYPE_DISPLAY="SQLite"
    else
        INSTALL_ARGS+=(--db "mysql")
        DB_TYPE_DISPLAY="MySQL"
    fi
    
    # Résumé
    echo ""
    echo "Configuration choisie:"
    if [ "$install_type" = "1" ]; then
        echo "- Installation locale"
    else
        echo "- Installation distante (Domaine: $domain_name)"
    fi
    echo "- Base de données: $DB_TYPE_DISPLAY"
    
    # Confirmation
    echo ""
    read -p "Confirmer et lancer l'installation ? (o/n) [o]: " confirm
    confirm=${confirm:-o}
    
    if [ "$confirm" = "o" ]; then
        # Exécuter avec les arguments
        "$SCRIPT_DIR/baikal_install.sh" "${INSTALL_ARGS[@]}"
    fi
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 4: Configuration SSL
option_setup_ssl() {
    clear
    show_header
    echo -e "${GREEN}=== Configuration SSL/HTTPS ===${NC}"
    echo ""
    echo "La configuration SSL est nécessaire pour:"
    echo "✓ Sécuriser l'accès distant"
    echo "✓ Protéger vos données"
    echo "✓ Éviter les avertissements de sécurité"
    echo ""
    echo "⚠️  Prérequis:"
    echo "- Nom de domaine configuré"
    echo "- DNS pointant vers ce serveur"
    echo "- Ports 80 et 443 ouverts"
    echo ""
    read -p "Les prérequis sont-ils remplis ? (o/n): " prereqs_ok
    
    if [ "$prereqs_ok" = "o" ]; then
        echo ""
        "$SCRIPT_DIR/setup_ssl.sh"
    else
        echo ""
        echo "Configurez d'abord:"
        echo "1. Votre nom de domaine (ex: cal.example.com)"
        echo "2. Le DNS (A record vers l'IP de ce serveur)"
        echo "3. Le firewall (ports 80 et 443)"
    fi
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 5: Configuration backups
option_setup_backups() {
    clear
    show_header
    echo -e "${GREEN}=== Configuration des backups automatiques ===${NC}"
    echo ""
    "$PROJECT_ROOT/maintenance/setup_backup.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 6: Monitoring
option_monitoring() {
    clear
    show_header
    echo -e "${GREEN}=== Monitoring du système ===${NC}"
    echo ""
    "$PROJECT_ROOT/maintenance/monitor.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 7: Mise à jour
option_update() {
    clear
    show_header
    echo -e "${GREEN}=== Mise à jour Baïkal ===${NC}"
    echo ""
    "$PROJECT_ROOT/maintenance/update.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Option 8: Documentation
option_documentation() {
    clear
    show_header
    echo -e "${CYAN}=== Documentation disponible ===${NC}"
    echo ""
    echo "📚 Guides disponibles:"
    echo ""
    echo "1. Guide d'installation (INSTALL.md)"
    echo "2. Configuration clients (CLIENTS.md)"
    echo "3. Guide de dépannage (TROUBLESHOOTING.md)"
    echo "4. Configuration MySQL (MYSQL.md)"
    echo "5. Sécurité (SECURITY.md)"
    echo ""
    echo "Fichiers d'information après installation:"
    echo "- /root/baikal_install_info.txt"
    echo "- /root/baikal_ssl_info.txt"
    echo "- /root/baikal_backup_config.txt"
    echo ""
    
    if [ -d "$PROJECT_ROOT/docs" ]; then
        echo "📂 Documentation disponible dans: $PROJECT_ROOT/docs/"
    fi
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Programme principal
main() {
    check_root
    
    while true; do
        show_header
        show_menu
        read -p "Votre choix [2]: " choice
        choice=${choice:-2}
        
        case $choice in
            1) option_check_prereqs ;;
            2) option_full_install ;;
            3) option_custom_install ;;
            4) option_setup_ssl ;;
            5) option_setup_backups ;;
            6) option_monitoring ;;
            7) option_update ;;
            8) option_documentation ;;
            9)
                clear
                echo -e "${CYAN}Merci d'avoir utilisé Baïkal Install Suite !${NC}"
                echo ""
                echo "📚 Ressources utiles:"
                echo "- Documentation: https://sabre.io/baikal/"
                echo "- Support: https://github.com/sabre-io/Baikal"
                echo ""
                echo "Pour relancer ce script: sudo $0"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Lancement
main
