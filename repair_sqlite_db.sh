#!/bin/bash

################################################################################
# Réparation automatique de la base de données SQLite Baïkal
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_PATH="/var/www/baikal/Specific/db/db.sqlite"
BACKUP_DIR="/var/backups/baikal/db_repair"
TEMP_DB="/tmp/baikal_db_temp_$$.sqlite"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         RÉPARATION BASE DE DONNÉES SQLITE                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Vérifier que la base existe
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}✗ Base de données introuvable: $DB_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠ ATTENTION ⚠${NC}"
echo "Ce script va tenter de réparer la base de données SQLite."
echo "Un backup sera créé avant toute modification."
echo ""
read -p "Voulez-vous continuer ? (o/n): " CONFIRM

if [ "$CONFIRM" != "o" ]; then
    echo "Annulation"
    exit 0
fi

# Créer le répertoire de backup
mkdir -p "$BACKUP_DIR"

# Étape 1: Backup
echo ""
echo -e "${BLUE}[1/6]${NC} Création du backup de sécurité"
echo "════════════════════════════════════════"
BACKUP_FILE="$BACKUP_DIR/db.sqlite.before_repair.$(date +%Y%m%d_%H%M%S)"
cp "$DB_PATH" "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup créé: $BACKUP_FILE${NC}"
    echo "  Taille: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    echo -e "${RED}✗ Échec du backup${NC}"
    exit 1
fi

# Étape 2: Vérifier l'intégrité actuelle
echo ""
echo -e "${BLUE}[2/6]${NC} Vérification de l'état actuel"
echo "════════════════════════════════════════"
INTEGRITY=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>&1)
echo "État: $INTEGRITY"

if [ "$INTEGRITY" = "ok" ]; then
    echo -e "${GREEN}✓ Base de données déjà intègre${NC}"
    echo ""
    echo "Aucune réparation nécessaire."
    echo "Le problème était probablement un faux positif."
    exit 0
fi

# Étape 3: Arrêter les services
echo ""
echo -e "${BLUE}[3/6]${NC} Arrêt temporaire des services"
echo "════════════════════════════════════════"
systemctl stop nginx
systemctl stop php*-fpm
echo -e "${GREEN}✓ Services arrêtés${NC}"
sleep 2

# Étape 4: Tentative de réparation - Méthode 1 (REINDEX)
echo ""
echo -e "${BLUE}[4/6]${NC} Méthode 1: Réindexation"
echo "════════════════════════════════════════"
REINDEX_RESULT=$(sqlite3 "$DB_PATH" "REINDEX;" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Réindexation réussie${NC}"
    
    # Vérifier si ça a résolu le problème
    INTEGRITY_AFTER=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>&1)
    if [ "$INTEGRITY_AFTER" = "ok" ]; then
        echo -e "${GREEN}✓✓✓ BASE RÉPARÉE !${NC}"
        systemctl start php*-fpm
        systemctl start nginx
        echo ""
        echo "La base de données a été réparée avec succès."
        echo "Backup disponible: $BACKUP_FILE"
        exit 0
    fi
else
    echo -e "${YELLOW}⚠ Réindexation a échoué${NC}"
fi

# Étape 5: Tentative de réparation - Méthode 2 (VACUUM)
echo ""
echo -e "${BLUE}[5/6]${NC} Méthode 2: VACUUM"
echo "════════════════════════════════════════"
VACUUM_RESULT=$(sqlite3 "$DB_PATH" "VACUUM;" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ VACUUM réussi${NC}"
    
    # Vérifier si ça a résolu le problème
    INTEGRITY_AFTER=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>&1)
    if [ "$INTEGRITY_AFTER" = "ok" ]; then
        echo -e "${GREEN}✓✓✓ BASE RÉPARÉE !${NC}"
        systemctl start php*-fpm
        systemctl start nginx
        echo ""
        echo "La base de données a été réparée avec succès."
        echo "Backup disponible: $BACKUP_FILE"
        exit 0
    fi
else
    echo -e "${YELLOW}⚠ VACUUM a échoué${NC}"
fi

# Étape 6: Méthode 3 (Export/Import - Reconstruction complète)
echo ""
echo -e "${BLUE}[6/6]${NC} Méthode 3: Reconstruction complète"
echo "════════════════════════════════════════"
echo "Export des données..."

# Exporter le schéma et les données
sqlite3 "$DB_PATH" ".dump" > "$TEMP_DB.sql" 2>&1

if [ $? -eq 0 ] && [ -s "$TEMP_DB.sql" ]; then
    echo -e "${GREEN}✓ Export réussi${NC}"
    echo "  Taille SQL: $(du -h "$TEMP_DB.sql" | cut -f1)"
    
    echo "Reconstruction de la base..."
    
    # Créer une nouvelle base propre
    sqlite3 "$TEMP_DB" < "$TEMP_DB.sql" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Reconstruction réussie${NC}"
        
        # Vérifier l'intégrité de la nouvelle base
        INTEGRITY_NEW=$(sqlite3 "$TEMP_DB" "PRAGMA integrity_check;" 2>&1)
        
        if [ "$INTEGRITY_NEW" = "ok" ]; then
            echo -e "${GREEN}✓ Nouvelle base intègre${NC}"
            
            # Remplacer l'ancienne base
            mv "$DB_PATH" "$DB_PATH.corrupted"
            mv "$TEMP_DB" "$DB_PATH"
            
            # Restaurer les permissions
            chown www-data:www-data "$DB_PATH"
            chmod 660 "$DB_PATH"
            
            echo -e "${GREEN}✓✓✓ BASE RECONSTRUITE AVEC SUCCÈS !${NC}"
            
            # Redémarrer les services
            systemctl start php*-fpm
            systemctl start nginx
            
            echo ""
            echo "La base de données a été reconstruite avec succès."
            echo "Ancienne base corrompue: $DB_PATH.corrupted"
            echo "Backup avant réparation: $BACKUP_FILE"
            echo "Fichier SQL: $TEMP_DB.sql"
            
            rm -f "$TEMP_DB.sql"
            exit 0
        else
            echo -e "${RED}✗ Nouvelle base toujours corrompue${NC}"
        fi
    else
        echo -e "${RED}✗ Reconstruction échouée${NC}"
    fi
else
    echo -e "${RED}✗ Export échoué${NC}"
fi

# Si on arrive ici, toutes les tentatives ont échoué
echo ""
echo -e "${RED}═══════════════════════════════════════════${NC}"
echo -e "${RED}✗✗✗ ÉCHEC DE LA RÉPARATION ✗✗✗${NC}"
echo -e "${RED}═══════════════════════════════════════════${NC}"
echo ""
echo "Toutes les méthodes de réparation ont échoué."
echo ""
echo -e "${YELLOW}OPTIONS:${NC}"
echo ""
echo "1. RESTAURER DEPUIS UN BACKUP"
echo "   cd /var/backups/baikal"
echo "   ls -lth  # Voir les backups disponibles"
echo "   # Restaurer le plus récent:"
echo "   sudo cp baikal_YYYYMMDD.tar.gz /tmp/"
echo "   cd /tmp && tar -xzf baikal_YYYYMMDD.tar.gz"
echo "   sudo cp var/www/baikal/Specific/db/db.sqlite /var/www/baikal/Specific/db/"
echo ""
echo "2. CONTACTER LE SUPPORT"
echo "   La base est sévèrement corrompue."
echo "   Consultez les forums Baïkal ou GitHub."
echo ""
echo "Fichiers disponibles pour analyse:"
echo "  - Base originale: $DB_PATH"
echo "  - Backup: $BACKUP_FILE"
echo "  - Export SQL: $TEMP_DB.sql"
echo ""

# Redémarrer les services quand même
systemctl start php*-fpm
systemctl start nginx

# Nettoyage
rm -f "$TEMP_DB" "$TEMP_DB.sql"

exit 1
