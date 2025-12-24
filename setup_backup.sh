#!/bin/bash

################################################################################
# Configuration des backups automatiques pour Baïkal
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Configuration des backups automatiques${NC}"
echo -e "${GREEN}========================================${NC}"

# Demande de la fréquence
echo ""
echo "Choisissez la fréquence des backups:"
echo "1) Quotidien (3h du matin)"
echo "2) Hebdomadaire (dimanche 3h)"
echo "3) Personnalisé"
read -p "Votre choix [1]: " BACKUP_FREQ
BACKUP_FREQ=${BACKUP_FREQ:-1}

# Définition du cron selon le choix
case $BACKUP_FREQ in
    1)
        CRON_SCHEDULE="0 3 * * *"
        FREQ_TEXT="quotidien à 3h"
        ;;
    2)
        CRON_SCHEDULE="0 3 * * 0"
        FREQ_TEXT="hebdomadaire (dimanche 3h)"
        ;;
    3)
        echo "Format cron (ex: 0 3 * * * pour 3h tous les jours)"
        read -p "Planning cron: " CRON_SCHEDULE
        FREQ_TEXT="personnalisé: $CRON_SCHEDULE"
        ;;
    *)
        log_error "Choix invalide"
        exit 1
        ;;
esac

# Copie du script de backup
log_info "Installation du script de backup..."
cp backup_baikal.sh /usr/local/bin/
chmod +x /usr/local/bin/backup_baikal.sh

# Ajout de la tâche cron
log_info "Configuration de la tâche cron..."
CRON_JOB="$CRON_SCHEDULE /usr/local/bin/backup_baikal.sh >> /var/log/baikal_backup.log 2>&1"

# Suppression des anciennes entrées si elles existent
crontab -l 2>/dev/null | grep -v "backup_baikal.sh" | crontab - || true

# Ajout de la nouvelle entrée
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Création du fichier de log
touch /var/log/baikal_backup.log
chmod 644 /var/log/baikal_backup.log

# Configuration de la rotation des logs
cat > /etc/logrotate.d/baikal-backup << 'LOGROTATE'
/var/log/baikal_backup.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
LOGROTATE

# Test du backup
log_info "Test du backup..."
/usr/local/bin/backup_baikal.sh

# Informations
cat > /root/baikal_backup_config.txt << EOF
========================================
Configuration des backups automatiques
========================================

Fréquence: $FREQ_TEXT
Cron: $CRON_SCHEDULE

Emplacement des backups: /var/backups/baikal
Rétention: 30 jours
Script: /usr/local/bin/backup_baikal.sh
Log: /var/log/baikal_backup.log

Commandes utiles:
- Voir les backups: ls -lh /var/backups/baikal
- Lancer un backup manuel: sudo /usr/local/bin/backup_baikal.sh
- Voir le log: sudo tail -f /var/log/baikal_backup.log
- Modifier le cron: sudo crontab -e

Restauration:
1. Arrêter les services:
   sudo systemctl stop nginx php*-fpm

2. Restaurer les données:
   sudo tar -xzf /var/backups/baikal/baikal_data_YYYYMMDD_HHMMSS.tar.gz -C /var/www/baikal/

3. Restaurer la base SQLite (si applicable):
   sudo cp /var/backups/baikal/baikal_db_YYYYMMDD_HHMMSS.sqlite /var/www/baikal/Specific/db/db.sqlite

4. Restaurer les permissions:
   sudo chown -R www-data:www-data /var/www/baikal
   sudo chmod -R 755 /var/www/baikal
   sudo chmod -R 770 /var/www/baikal/Specific
   sudo chmod -R 770 /var/www/baikal/config

5. Redémarrer les services:
   sudo systemctl start nginx php*-fpm

EOF

cat /root/baikal_backup_config.txt

log_info "Configuration des backups terminée !"
log_info "Informations sauvegardées dans: /root/baikal_backup_config.txt"
log_info "Premier backup effectué avec succès"
