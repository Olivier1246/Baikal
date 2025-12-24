#!/bin/bash

################################################################################
# Résolution du conflit de port 80 pour Nginx
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Diagnostic du conflit de port 80${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Vérifier quel processus utilise le port 80
echo -e "${YELLOW}Processus utilisant le port 80:${NC}"
netstat -tulpn | grep :80 || ss -tulpn | grep :80

echo ""
echo -e "${YELLOW}Processus détaillés:${NC}"
lsof -i :80 2>/dev/null || fuser -v 80/tcp 2>/dev/null

echo ""
echo -e "${BLUE}========================================${NC}"

# Identifier les services web courants
APACHE_RUNNING=false
LIGHTTPD_RUNNING=false
OTHER_WEB=false

if systemctl is-active --quiet apache2; then
    APACHE_RUNNING=true
    echo -e "${YELLOW}⚠ Apache2 est actif${NC}"
fi

if systemctl is-active --quiet lighttpd; then
    LIGHTTPD_RUNNING=true
    echo -e "${YELLOW}⚠ Lighttpd est actif${NC}"
fi

# Vérifier d'autres processus sur le port 80
PORT_PROCESS=$(lsof -ti :80 2>/dev/null | head -1)
if [ ! -z "$PORT_PROCESS" ]; then
    PROCESS_NAME=$(ps -p $PORT_PROCESS -o comm= 2>/dev/null)
    if [ "$PROCESS_NAME" != "apache2" ] && [ "$PROCESS_NAME" != "lighttpd" ] && [ "$PROCESS_NAME" != "nginx" ]; then
        OTHER_WEB=true
        echo -e "${YELLOW}⚠ Processus inconnu ($PROCESS_NAME) utilise le port 80${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Solutions disponibles${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$APACHE_RUNNING" = true ]; then
    echo -e "${GREEN}Solution pour Apache2:${NC}"
    echo "1. Arrêter Apache2:"
    echo "   sudo systemctl stop apache2"
    echo "   sudo systemctl disable apache2"
    echo ""
    read -p "Voulez-vous arrêter Apache2 maintenant? (o/n): " stop_apache
    if [ "$stop_apache" = "o" ]; then
        echo -e "${YELLOW}Arrêt d'Apache2...${NC}"
        systemctl stop apache2
        systemctl disable apache2
        echo -e "${GREEN}✓ Apache2 arrêté et désactivé${NC}"
    fi
fi

if [ "$LIGHTTPD_RUNNING" = true ]; then
    echo -e "${GREEN}Solution pour Lighttpd:${NC}"
    echo "1. Arrêter Lighttpd:"
    echo "   sudo systemctl stop lighttpd"
    echo "   sudo systemctl disable lighttpd"
    echo ""
    read -p "Voulez-vous arrêter Lighttpd maintenant? (o/n): " stop_light
    if [ "$stop_light" = "o" ]; then
        echo -e "${YELLOW}Arrêt de Lighttpd...${NC}"
        systemctl stop lighttpd
        systemctl disable lighttpd
        echo -e "${GREEN}✓ Lighttpd arrêté et désactivé${NC}"
    fi
fi

if [ "$OTHER_WEB" = true ]; then
    echo -e "${YELLOW}Un autre processus utilise le port 80.${NC}"
    echo "PID: $PORT_PROCESS"
    echo "Nom: $PROCESS_NAME"
    echo ""
    echo "Pour le tuer:"
    echo "   sudo kill $PORT_PROCESS"
    echo ""
    read -p "Voulez-vous arrêter ce processus maintenant? (o/n): " kill_process
    if [ "$kill_process" = "o" ]; then
        kill $PORT_PROCESS
        sleep 2
        echo -e "${GREEN}✓ Processus arrêté${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Redémarrage de Nginx${NC}"
echo -e "${BLUE}========================================${NC}"

# Attendre un peu que le port se libère
sleep 2

# Vérifier que le port est maintenant libre
if netstat -tulpn | grep -q :80; then
    echo -e "${RED}✗ Le port 80 est toujours occupé${NC}"
    echo "Processus restants:"
    netstat -tulpn | grep :80
    exit 1
else
    echo -e "${GREEN}✓ Port 80 maintenant libre${NC}"
fi

# Redémarrer Nginx
echo -e "${YELLOW}Démarrage de Nginx...${NC}"
systemctl start nginx

# Vérifier le status
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx démarré avec succès !${NC}"
    echo ""
    systemctl status nginx --no-pager
else
    echo -e "${RED}✗ Nginx n'a pas pu démarrer${NC}"
    echo ""
    echo "Logs d'erreur:"
    journalctl -u nginx --no-pager -n 20
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Problème résolu !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Nginx est maintenant actif sur le port 80"
echo "Testez: curl http://localhost/"
