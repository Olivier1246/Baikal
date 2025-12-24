#!/bin/bash
# Configuration backups automatiques

set -e
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

[ "$EUID" -ne 0 ] && echo "Erreur: root requis" && exit 1

echo "Configuration des backups automatiques"
echo "1) Quotidien (3h du matin)"
echo "2) Hebdomadaire (Dimanche 3h)"
read -p "Choix [1]: " FREQ
FREQ=${FREQ:-1}

cp "$(dirname $0)/backup.sh" /usr/local/bin/backup_baikal.sh
chmod +x /usr/local/bin/backup_baikal.sh

if [ "$FREQ" = "1" ]; then
    CRON="0 3 * * * /usr/local/bin/backup_baikal.sh >> /var/log/baikal_backup.log 2>&1"
else
    CRON="0 3 * * 0 /usr/local/bin/backup_baikal.sh >> /var/log/baikal_backup.log 2>&1"
fi

(crontab -l 2>/dev/null | grep -v backup_baikal; echo "$CRON") | crontab -

cat > /root/baikal_backup_config.txt << EOFINFO
Backups automatiques configurés
Date: $(date)
Fréquence: $([ "$FREQ" = "1" ] && echo "Quotidien" || echo "Hebdomadaire")
Script: /usr/local/bin/backup_baikal.sh
Log: /var/log/baikal_backup.log
Destination: /var/backups/baikal/
Rétention: 30 jours
EOFINFO

log_info "Backups automatiques configurés avec succès!"
cat /root/baikal_backup_config.txt
