#!/bin/bash

################################################################################
# Vérification des prérequis système pour Baïkal
# Projet: Baïkal Install Suite
# Fichier: install/check_prereqs.sh
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
WARNINGS=0
ERRORS=0

# Fonctions
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

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Vérification des prérequis Baïkal${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# 1. Privilèges root
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
ROOT_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$ROOT_SPACE" -gt 1 ]; then
    check_ok "Espace disponible: ${ROOT_SPACE}G"
else
    check_warning "Espace limité: ${ROOT_SPACE}G (1G+ recommandé)"
fi

VAR_SPACE=$(df -BG /var | awk 'NR==2 {print $4}' | sed 's/G//')
echo "   /var: ${VAR_SPACE}G disponible"
echo ""

# 4. Mémoire RAM
echo -e "${BLUE}4. Mémoire:${NC}"
TOTAL_RAM=$(free -m | awk 'NR==2 {print $2}')
if [ "$TOTAL_RAM" -ge 1024 ]; then
    check_ok "RAM: ${TOTAL_RAM}Mo (recommandé)"
elif [ "$TOTAL_RAM" -ge 512 ]; then
    check_warning "RAM: ${TOTAL_RAM}Mo (minimum, 1Go recommandé)"
else
    check_error "RAM insuffisante: ${TOTAL_RAM}Mo (512Mo minimum)"
fi
echo ""

# 5. Connectivité
echo -e "${BLUE}5. Connectivité:${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    check_ok "Connexion Internet active"
else
    check_error "Pas de connexion Internet (requise pour l'installation)"
fi

if command -v nslookup &> /dev/null && nslookup google.com &> /dev/null; then
    check_ok "Résolution DNS fonctionnelle"
else
    check_warning "Problème de résolution DNS"
fi
echo ""

# 6. Ports
echo -e "${BLUE}6. Ports réseau:${NC}"
if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":80 "; then
        check_warning "Port 80 déjà utilisé"
    else
        check_ok "Port 80 disponible"
    fi
    
    if ss -tuln | grep -q ":443 "; then
        check_warning "Port 443 déjà utilisé"
    else
        check_ok "Port 443 disponible"
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":80 "; then
        check_warning "Port 80 déjà utilisé"
    else
        check_ok "Port 80 disponible"
    fi
    
    if netstat -tuln | grep -q ":443 "; then
        check_warning "Port 443 déjà utilisé"
    else
        check_ok "Port 443 disponible"
    fi
else
    check_warning "Impossible de vérifier les ports (netstat/ss non disponible)"
fi
echo ""

# 7. Outils système
echo -e "${BLUE}7. Outils système:${NC}"
TOOLS=("wget" "curl" "unzip" "tar" "systemctl")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
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
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        check_warning "$service est actif (peut causer des conflits avec Nginx)"
        ((CONFLICTS++))
    fi
done
if [ "$CONFLICTS" -eq 0 ]; then
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

# 10. Firewall
echo -e "${BLUE}10. Firewall:${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
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
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Résumé${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ Système prêt pour l'installation !${NC}"
    echo ""
    echo "Prochaine étape: sudo ./install/baikal_install.sh"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS avertissement(s) détecté(s)${NC}"
    echo ""
    echo "L'installation peut continuer mais vérifiez les avertissements."
    echo "Prochaine étape: sudo ./install/baikal_install.sh"
else
    echo -e "${RED}✗ $ERRORS erreur(s) et $WARNINGS avertissement(s)${NC}"
    echo ""
    echo "Corrigez les erreurs avant de continuer."
    exit 1
fi

echo ""
echo -e "${BLUE}Informations système:${NC}"
[ -f /etc/os-release ] && . /etc/os-release && echo "Distribution: $NAME $VERSION"
echo "RAM: ${TOTAL_RAM}Mo"
echo "Espace disque: ${ROOT_SPACE}G disponible"
echo ""

exit 0
