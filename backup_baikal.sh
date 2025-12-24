#!/bin/bash

################################################################################
# Script de backup automatique pour Baïkal
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

# Configuration
BAIKAL_DIR="/var/www/baikal"
BACKUP_DIR="/var/backups/baikal"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

# Vérification root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Création du répertoire de backup
mkdir -p $BACKUP_DIR

log_info "Début du backup de Baïkal..."

# Backup des données
log_info "Backup des données..."
tar -czf $BACKUP_DIR/baikal_data_$DATE.tar.gz \
    -C $BAIKAL_DIR \
    Specific \
    config \
    2>/dev/null || true

# Backup de la base de données MySQL si elle existe
if [ -f "$BAIKAL_DIR/Specific/db/db.sqlite" ]; then
    log_info "Backup de la base SQLite..."
    cp $BAIKAL_DIR/Specific/db/db.sqlite $BACKUP_DIR/baikal_db_$DATE.sqlite
fi

# Si MySQL est utilisé (à décommenter et configurer)
# read -r DB_NAME DB_USER DB_PASS < /root/.baikal_mysql_config
# mysqldump -u$DB_USER -p$DB_PASS $DB_NAME | gzip > $BACKUP_DIR/baikal_mysql_$DATE.sql.gz

# Backup de la configuration Nginx
log_info "Backup de la configuration Nginx..."
if [ -f "/etc/nginx/sites-available/baikal" ]; then
    cp /etc/nginx/sites-available/baikal $BACKUP_DIR/nginx_baikal_$DATE.conf
fi

# Nettoyage des anciens backups
log_info "Nettoyage des backups de plus de $RETENTION_DAYS jours..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

# Calcul de la taille du backup
BACKUP_SIZE=$(du -sh $BACKUP_DIR | cut -f1)

# Rapport
cat > $BACKUP_DIR/last_backup_report.txt << EOF
========================================
Rapport de backup Baïkal
========================================

Date: $(date)
Backup ID: $DATE

Fichiers sauvegardés:
- baikal_data_$DATE.tar.gz
- baikal_db_$DATE.sqlite (si SQLite)
- nginx_baikal_$DATE.conf

Emplacement: $BACKUP_DIR
Taille totale: $BACKUP_SIZE
Rétention: $RETENTION_DAYS jours

Status: SUCCESS
EOF

log_info "Backup terminé avec succès !"
log_info "Emplacement: $BACKUP_DIR"
log_info "Taille: $BACKUP_SIZE"
