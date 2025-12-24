#!/bin/bash

################################################################################
# Script de démarrage rapide - Installation guidée de Baïkal
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ____        ______            __                          ║
║    / __ )____ _/  _/ /______ _   / /                          ║
║   / __  / __ `/_ // //_/ __ `/  / /                           ║
║  / /_/ / /_/ /_ |/ ,< / /_/ /  / /                            ║
║ /_____/\__,_/___/_/|_|\__,_/  /_/                             ║
║                                                               ║
║           Serveur CalDAV/CardDAV auto-hébergé                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}Bienvenue dans l'installation de Baïkal !${NC}"
echo ""
echo "Ce script va vous guider à travers l'installation complète"
echo "d'un serveur CalDAV/CardDAV pour synchroniser vos calendriers"
echo "et contacts sur tous vos appareils."
echo ""

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Erreur: Ce script doit être exécuté avec sudo${NC}"
    echo "Utilisez: sudo ./start.sh"
    exit 1
fi

# Menu principal
while true; do
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}Menu principal${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "1. Vérifier les prérequis"
    echo "2. Installation complète (recommandé)"
    echo "3. Installation personnalisée"
    echo "4. Configuration SSL (après installation)"
    echo "5. Configuration des backups"
    echo "6. Monitoring du système"
    echo "7. Afficher le guide des clients"
    echo "8. Afficher la documentation"
    echo "9. Quitter"
    echo ""
    read -p "Votre choix [2]: " choice
    choice=${choice:-2}
    
    case $choice in
        1)
            echo ""
            echo -e "${GREEN}=== Vérification des prérequis ===${NC}"
            echo ""
            ./check_prereqs.sh
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            clear
            ;;
            
        2)
            clear
            echo -e "${GREEN}=== Installation complète de Baïkal ===${NC}"
            echo ""
            echo "Cette installation va:"
            echo "✓ Installer toutes les dépendances"
            echo "✓ Configurer Baïkal avec SQLite"
            echo "✓ Configurer Nginx"
            echo "✓ Créer la structure de base"
            echo ""
            read -p "Continuer ? (o/n) [o]: " confirm
            confirm=${confirm:-o}
            
            if [ "$confirm" = "o" ]; then
                echo ""
                ./baikal_install.sh
                
                echo ""
                echo -e "${GREEN}Installation terminée !${NC}"
                echo ""
                echo "Prochaines étapes:"
                echo "1. Configuration web: Ouvrez http://localhost/ dans votre navigateur"
                echo "2. Si accès distant souhaité: Lancez l'option 4 (Configuration SSL)"
                echo "3. Configuration backups: Option 5"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                clear
            fi
            ;;
            
        3)
            clear
            echo -e "${GREEN}=== Installation personnalisée ===${NC}"
            echo ""
            echo "Type d'installation:"
            echo "1. Local uniquement (localhost)"
            echo "2. Distant (avec nom de domaine)"
            read -p "Votre choix [1]: " install_type
            install_type=${install_type:-1}
            
            echo ""
            echo "Base de données:"
            echo "1. SQLite (recommandé pour usage personnel)"
            echo "2. MySQL (pour usage intensif)"
            read -p "Votre choix [1]: " db_type
            db_type=${db_type:-1}
            
            echo ""
            echo "Configuration choisie:"
            if [ "$install_type" = "1" ]; then
                echo "- Installation locale"
            else
                echo "- Installation distante"
            fi
            
            if [ "$db_type" = "1" ]; then
                echo "- Base de données SQLite"
            else
                echo "- Base de données MySQL"
            fi
            
            echo ""
            read -p "Confirmer et lancer l'installation ? (o/n) [o]: " confirm
            confirm=${confirm:-o}
            
            if [ "$confirm" = "o" ]; then
                ./baikal_install.sh
            fi
            
            read -p "Appuyez sur Entrée pour continuer..."
            clear
            ;;
            
        4)
            clear
            echo -e "${GREEN}=== Configuration SSL ===${NC}"
            echo ""
            echo "La configuration SSL est nécessaire pour:"
            echo "✓ Sécuriser l'accès distant"
            echo "✓ Protéger vos données"
            echo "✓ Éviter les avertissements de sécurité"
            echo ""
            echo "Prérequis:"
            echo "- Nom de domaine configuré"
            echo "- DNS pointant vers ce serveur"
            echo "- Ports 80 et 443 ouverts"
            echo ""
            read -p "Les prérequis sont-ils remplis ? (o/n): " prereqs_ok
            
            if [ "$prereqs_ok" = "o" ]; then
                echo ""
                ./setup_ssl.sh
            else
                echo ""
                echo "Configurez d'abord:"
                echo "1. Votre nom de domaine (ex: cal.example.com)"
                echo "2. Le DNS (A record vers l'IP de ce serveur)"
                echo "3. Le firewall (ports 80 et 443)"
            fi
            
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            clear
            ;;
            
        5)
            clear
            echo -e "${GREEN}=== Configuration des backups ===${NC}"
            echo ""
            ./setup_backup.sh
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            clear
            ;;
            
        6)
            clear
            echo -e "${GREEN}=== Monitoring du système ===${NC}"
            echo ""
            ./monitor_baikal.sh
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            clear
            ;;
            
        7)
            clear
            echo -e "${GREEN}=== Guide de configuration des clients ===${NC}"
            echo ""
            less GUIDE_CLIENTS.txt
            clear
            ;;
            
        8)
            clear
            echo -e "${CYAN}=== Documentation disponible ===${NC}"
            echo ""
            echo "1. README.txt - Guide complet d'installation et d'utilisation"
            echo "2. GUIDE_CLIENTS.txt - Configuration iOS, Android, Desktop, etc."
            echo "3. MYSQL_CONFIG.txt - Configuration avancée MySQL"
            echo ""
            echo "Fichiers d'information après installation:"
            echo "- /root/baikal_install_info.txt"
            echo "- /root/baikal_ssl_info.txt"
            echo "- /root/baikal_backup_config.txt"
            echo ""
            read -p "Afficher le README complet ? (o/n): " show_readme
            
            if [ "$show_readme" = "o" ]; then
                clear
                less README.txt
            fi
            clear
            ;;
            
        9)
            clear
            echo -e "${CYAN}Merci d'avoir utilisé l'installateur Baïkal !${NC}"
            echo ""
            echo "Ressources utiles:"
            echo "- Documentation: https://sabre.io/baikal/"
            echo "- Support: https://github.com/sabre-io/Baikal"
            echo ""
            echo "Pour relancer ce script: sudo ./start.sh"
            echo ""
            exit 0
            ;;
            
        *)
            echo -e "${RED}Choix invalide${NC}"
            sleep 1
            clear
            ;;
    esac
done
