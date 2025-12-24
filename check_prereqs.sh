#!/bin/bash

################################################################################
# Vérification des prérequis pour l'installation de Baïkal
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Vérification des prérequis Baïkal${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Compteurs
WARNINGS=0
ERRORS=0

# Fonction pour les checks
check_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

check_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# 1. Vérification des privilèges root
echo -e "${BLUE}1. Privilèges:${NC}"
if [ "$EUID" -eq 0 ]; then
    check_ok "Exécuté en tant que root"
else
    check_error "Ce script doit être exécuté avec sudo"
fi
echo ""

# 2. Système d'exploitation
echo -e "${BLUE}2. Système d'exploitation:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   Distribution: $NAME $VERSION"
    
    if [[ "$ID" == "debian" ]] || [[ "$ID" == "ubuntu" ]]; then
        check_ok "Distribution supportée"
    else
        check_warning "Distribution non testée (optimisé pour Debian/Ubuntu)"
    fi
else
    check_warning "Impossible de détecter la distribution"
fi
echo ""

# 3. Espace disque
echo -e "${BLUE}3. Espace disque:${NC}"
ROOT_SPACE=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
if (( $(echo "$ROOT_SPACE > 1" | bc -l) )); then
    check_ok "Espace disponible: ${ROOT_SPACE}G"
else
    check_warning "Espace limité: ${ROOT_SPACE}G (1G+ recommandé)"
fi

VAR_SPACE=$(df -h /var | awk 'NR==2 {print $4}' | sed 's/G//')
echo "   /var: ${VAR_SPACE}G disponible"
echo ""

# 4. Mémoire RAM
echo -e "${BLUE}4. Mémoire:${NC}"
TOTAL_RAM=$(free -m | awk 'NR==2 {print $2}')
if [ $TOTAL_RAM -ge 1024 ]; then
    check_ok "RAM: ${TOTAL_RAM}Mo (recommandé)"
elif [ $TOTAL_RAM -ge 512 ]; then
    check_warning "RAM: ${TOTAL_RAM}Mo (minimum, 1Go recommandé)"
else
    check_error "RAM insuffisante: ${TOTAL_RAM}Mo (512Mo minimum)"
fi
echo ""

# 5. Connexion Internet
echo -e "${BLUE}5. Connectivité:${NC}"
if ping -c 1 google.com &> /dev/null; then
    check_ok "Connexion Internet active"
else
    check_error "Pas de connexion Internet (requise pour l'installation)"
fi

# Test DNS
if nslookup google.com &> /dev/null; then
    check_ok "Résolution DNS fonctionnelle"
else
    check_warning "Problème de résolution DNS"
fi
echo ""

# 6. Ports
echo -e "${BLUE}6. Ports réseau:${NC}"
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    check_warning "Port 80 déjà utilisé"
else
    check_ok "Port 80 disponible"
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    check_warning "Port 443 déjà utilisé"
else
    check_ok "Port 443 disponible"
fi
echo ""

# 7. Paquets requis
echo -e "${BLUE}7. Outils système:${NC}"
TOOLS=("wget" "curl" "unzip" "tar" "systemctl")
for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        check_ok "$tool installé"
    else
        check_warning "$tool non installé (sera installé)"
    fi
done
echo ""

# 8. Services conflictuels
echo -e "${BLUE}8. Services conflictuels:${NC}"
SERVICES=("apache2" "lighttpd")
CONFLICTS=0
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        check_warning "$service est actif (peut causer des conflits avec Nginx)"
        ((CONFLICTS++))
    fi
done
if [ $CONFLICTS -eq 0 ]; then
    check_ok "Aucun service web conflictuel détecté"
fi
echo ""

# 9. Répertoire d'installation
echo -e "${BLUE}9. Répertoire d'installation:${NC}"
if [ -d "/var/www/baikal" ]; then
    check_warning "/var/www/baikal existe déjà (sera écrasé)"
else
    check_ok "/var/www/baikal disponible"
fi
echo ""

# 10. Base de données existante
echo -e "${BLUE}10. Base de données:${NC}"
if command -v mysql &> /dev/null; then
    check_warning "MySQL déjà installé"
    if mysql -e "SHOW DATABASES LIKE 'baikal';" 2>/dev/null | grep -q baikal; then
        check_warning "Base 'baikal' existe déjà"
    fi
else
    check_ok "MySQL non installé"
fi
echo ""

# 11. Certificats SSL existants
echo -e "${BLUE}11. Certificats SSL:${NC}"
if [ -d "/etc/letsencrypt" ]; then
    check_warning "Let's Encrypt déjà configuré"
    CERTS=$(find /etc/letsencrypt/live -maxdepth 1 -type d ! -name "live" ! -name "README" 2>/dev/null | wc -l)
    if [ $CERTS -gt 0 ]; then
        echo "   $CERTS certificat(s) existant(s)"
    fi
else
    check_ok "Pas de certificats Let's Encrypt"
fi
echo ""

# 12. Firewall
echo -e "${BLUE}12. Firewall:${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    echo "   UFW: $UFW_STATUS"
    if [[ "$UFW_STATUS" == *"active"* ]]; then
        check_warning "UFW actif - vérifier que les ports 80/443 sont ouverts"
    else
        check_ok "UFW installé mais inactif"
    fi
else
    check_warning "UFW non installé (recommandé pour la sécurité)"
fi
echo ""

# Résumé
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Résumé${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Système prêt pour l'installation !${NC}"
    echo ""
    echo "Prochaine étape: sudo ./baikal_install.sh"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS avertissement(s) détecté(s)${NC}"
    echo ""
    echo "L'installation peut continuer mais vérifiez les avertissements."
    echo "Prochaine étape: sudo ./baikal_install.sh"
else
    echo -e "${RED}✗ $ERRORS erreur(s) et $WARNINGS avertissement(s)${NC}"
    echo ""
    echo "Corrigez les erreurs avant de continuer."
    exit 1
fi

echo ""
echo -e "${BLUE}Informations système:${NC}"
echo "Distribution: $NAME $VERSION"
echo "RAM: ${TOTAL_RAM}Mo"
echo "Espace disque: ${ROOT_SPACE}G disponible"
echo ""

# Questions de configuration
echo -e "${BLUE}Configuration souhaitée:${NC}"
read -p "Type d'installation (local/distant): " INSTALL_TYPE
if [ "$INSTALL_TYPE" = "distant" ]; then
    read -p "Nom de domaine (ex: cal.example.com): " DOMAIN
    echo ""
    echo "Pour l'installation distante, vous devrez:"
    echo "1. Configurer le DNS pour pointer vers ce serveur"
    echo "2. Ouvrir les ports 80 et 443"
    echo "3. Exécuter setup_ssl.sh après l'installation"
fi

read -p "Base de données (sqlite/mysql): " DB_TYPE
echo ""

echo -e "${GREEN}Configuration notée !${NC}"
echo ""
echo "Lancer l'installation: sudo ./baikal_install.sh"
