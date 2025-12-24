#!/bin/bash

################################################################################
# Script de monitoring et maintenance pour Baïkal
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BAIKAL_DIR="/var/www/baikal"
LOG_DIR="/var/log/nginx"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Monitoring Baïkal${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour afficher le status d'un service
check_service() {
    local service=$1
    local display_name=$2
    
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓${NC} $display_name: ${GREEN}Actif${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $display_name: ${RED}Inactif${NC}"
        return 1
    fi
}

# Fonction pour vérifier l'espace disque
check_disk_space() {
    local path=$1
    local threshold=$2
    local usage=$(df -h $path | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ $usage -lt $threshold ]; then
        echo -e "${GREEN}✓${NC} Espace disque ($path): ${usage}% utilisé"
        return 0
    elif [ $usage -lt 90 ]; then
        echo -e "${YELLOW}⚠${NC} Espace disque ($path): ${YELLOW}${usage}% utilisé${NC}"
        return 1
    else
        echo -e "${RED}✗${NC} Espace disque ($path): ${RED}${usage}% utilisé${NC}"
        return 2
    fi
}

# Fonction pour compter les erreurs dans les logs
check_logs() {
    local log_file=$1
    local display_name=$2
    
    if [ -f "$log_file" ]; then
        local errors=$(grep -c "error" $log_file 2>/dev/null || echo 0)
        if [ $errors -eq 0 ]; then
            echo -e "${GREEN}✓${NC} $display_name: Aucune erreur"
        elif [ $errors -lt 10 ]; then
            echo -e "${YELLOW}⚠${NC} $display_name: ${YELLOW}$errors erreurs${NC}"
        else
            echo -e "${RED}✗${NC} $display_name: ${RED}$errors erreurs${NC}"
        fi
    else
        echo -e "${YELLOW}⚠${NC} $display_name: Fichier log introuvable"
    fi
}

# Vérification des services
echo -e "${BLUE}Services:${NC}"
check_service nginx "Nginx"
check_service "php*-fpm" "PHP-FPM"
echo ""

# Vérification de l'espace disque
echo -e "${BLUE}Espace disque:${NC}"
check_disk_space "/" 80
check_disk_space "/var/www" 80
check_disk_space "/var/backups" 80
echo ""

# Vérification de la base de données
echo -e "${BLUE}Base de données:${NC}"
if [ -f "$BAIKAL_DIR/Specific/db/db.sqlite" ]; then
    DB_SIZE=$(du -h "$BAIKAL_DIR/Specific/db/db.sqlite" | cut -f1)
    echo -e "${GREEN}✓${NC} SQLite: Base trouvée (${DB_SIZE})"
else
    echo -e "${YELLOW}⚠${NC} SQLite: Base non trouvée (utilisation de MySQL?)"
fi
echo ""

# Vérification des logs
echo -e "${BLUE}Logs (dernières 24h):${NC}"
check_logs "$LOG_DIR/baikal_error.log" "Nginx erreurs"
echo ""

# Statistiques d'utilisation
echo -e "${BLUE}Statistiques d'utilisation:${NC}"
if [ -f "$LOG_DIR/baikal_access.log" ]; then
    REQUESTS_TODAY=$(grep "$(date +%d/%b/%Y)" $LOG_DIR/baikal_access.log 2>/dev/null | wc -l)
    echo -e "Requêtes aujourd'hui: ${REQUESTS_TODAY}"
    
    UNIQUE_IPS=$(grep "$(date +%d/%b/%Y)" $LOG_DIR/baikal_access.log 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
    echo -e "IPs uniques: ${UNIQUE_IPS}"
else
    echo -e "${YELLOW}⚠${NC} Log d'accès introuvable"
fi
echo ""

# Vérification SSL
echo -e "${BLUE}Certificat SSL:${NC}"
if [ -d "/etc/letsencrypt/live" ]; then
    CERT_DIRS=$(find /etc/letsencrypt/live -maxdepth 1 -type d ! -name "live" ! -name "README")
    if [ ! -z "$CERT_DIRS" ]; then
        for cert_dir in $CERT_DIRS; do
            domain=$(basename $cert_dir)
            if [ -f "$cert_dir/cert.pem" ]; then
                expiry=$(openssl x509 -enddate -noout -in "$cert_dir/cert.pem" | cut -d= -f2)
                expiry_epoch=$(date -d "$expiry" +%s)
                now_epoch=$(date +%s)
                days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
                
                if [ $days_left -gt 30 ]; then
                    echo -e "${GREEN}✓${NC} $domain: Expire dans ${days_left} jours"
                elif [ $days_left -gt 7 ]; then
                    echo -e "${YELLOW}⚠${NC} $domain: ${YELLOW}Expire dans ${days_left} jours${NC}"
                else
                    echo -e "${RED}✗${NC} $domain: ${RED}Expire dans ${days_left} jours${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} Aucun certificat trouvé"
    fi
else
    echo -e "${YELLOW}⚠${NC} Let's Encrypt non configuré"
fi
echo ""

# Vérification des backups
echo -e "${BLUE}Backups:${NC}"
if [ -d "/var/backups/baikal" ]; then
    LATEST_BACKUP=$(ls -t /var/backups/baikal/baikal_data_*.tar.gz 2>/dev/null | head -1)
    if [ ! -z "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d' ' -f1)
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        echo -e "${GREEN}✓${NC} Dernier backup: ${BACKUP_DATE} (${BACKUP_SIZE})"
        
        # Vérifier l'âge du backup
        BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 86400 ))
        if [ $BACKUP_AGE -gt 7 ]; then
            echo -e "${YELLOW}⚠${NC} Attention: Le dernier backup date de ${BACKUP_AGE} jours"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Aucun backup trouvé"
    fi
else
    echo -e "${YELLOW}⚠${NC} Répertoire de backup non trouvé"
fi
echo ""

# Vérification de la connectivité
echo -e "${BLUE}Connectivité:${NC}"
if command -v curl &> /dev/null; then
    # Test local
    if curl -s -f http://localhost/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Accès local: OK"
    else
        echo -e "${RED}✗${NC} Accès local: ${RED}Échec${NC}"
    fi
    
    # Test du port HTTPS
    if netstat -tuln | grep -q ":443 "; then
        echo -e "${GREEN}✓${NC} Port HTTPS 443: Ouvert"
    else
        echo -e "${YELLOW}⚠${NC} Port HTTPS 443: Fermé ou non utilisé"
    fi
else
    echo -e "${YELLOW}⚠${NC} curl non installé, impossible de tester la connectivité"
fi
echo ""

# Permissions
echo -e "${BLUE}Permissions:${NC}"
if [ -d "$BAIKAL_DIR/Specific" ]; then
    SPECIFIC_PERMS=$(stat -c %a "$BAIKAL_DIR/Specific")
    if [ "$SPECIFIC_PERMS" = "770" ]; then
        echo -e "${GREEN}✓${NC} Permissions Specific: OK (770)"
    else
        echo -e "${YELLOW}⚠${NC} Permissions Specific: ${YELLOW}$SPECIFIC_PERMS (attendu: 770)${NC}"
    fi
fi

if [ -d "$BAIKAL_DIR/config" ]; then
    CONFIG_PERMS=$(stat -c %a "$BAIKAL_DIR/config")
    if [ "$CONFIG_PERMS" = "770" ]; then
        echo -e "${GREEN}✓${NC} Permissions config: OK (770)"
    else
        echo -e "${YELLOW}⚠${NC} Permissions config: ${YELLOW}$CONFIG_PERMS (attendu: 770)${NC}"
    fi
fi
echo ""

# Résumé
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Résumé${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Pour plus de détails, consultez:"
echo "- Logs Nginx: $LOG_DIR/baikal_*.log"
echo "- Logs système: journalctl -u nginx -u php*-fpm"
echo "- Interface web: https://votre-domaine.com/"
echo ""
echo "Commandes de maintenance:"
echo "- Redémarrer Nginx: sudo systemctl restart nginx"
echo "- Redémarrer PHP-FPM: sudo systemctl restart php*-fpm"
echo "- Backup manuel: sudo /usr/local/bin/backup_baikal.sh"
echo "- Renouveler SSL: sudo certbot renew"
