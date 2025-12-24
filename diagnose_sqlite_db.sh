#!/bin/bash

################################################################################
# Diagnostic approfondi de la base de données SQLite Baïkal
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_PATH="/var/www/baikal/Specific/db/db.sqlite"
BACKUP_DIR="/var/backups/baikal/db_repair"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         DIAGNOSTIC BASE DE DONNÉES SQLITE                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Vérifier que la base existe
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}✗ Base de données introuvable: $DB_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}[1/8]${NC} Informations générales"
echo "════════════════════════════════════════"
echo "Chemin: $DB_PATH"
echo "Taille: $(du -h "$DB_PATH" | cut -f1)"
echo "Propriétaire: $(stat -c %U:%G "$DB_PATH")"
echo "Permissions: $(stat -c %a "$DB_PATH")"
echo "Dernière modification: $(stat -c %y "$DB_PATH" | cut -d'.' -f1)"
echo ""

echo -e "${BLUE}[2/8]${NC} Test d'intégrité PRAGMA integrity_check"
echo "════════════════════════════════════════"
INTEGRITY=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>&1)
echo "Résultat: $INTEGRITY"

if [ "$INTEGRITY" = "ok" ]; then
    echo -e "${GREEN}✓ Intégrité: OK${NC}"
    INTEGRITY_OK=true
else
    echo -e "${RED}✗ Intégrité: PROBLÈME DÉTECTÉ${NC}"
    echo "Détails:"
    echo "$INTEGRITY" | head -20
    INTEGRITY_OK=false
fi
echo ""

echo -e "${BLUE}[3/8]${NC} Test d'intégrité PRAGMA quick_check"
echo "════════════════════════════════════════"
QUICK_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA quick_check;" 2>&1)
echo "Résultat: $QUICK_CHECK"

if [ "$QUICK_CHECK" = "ok" ]; then
    echo -e "${GREEN}✓ Quick check: OK${NC}"
else
    echo -e "${RED}✗ Quick check: PROBLÈME${NC}"
fi
echo ""

echo -e "${BLUE}[4/8]${NC} Vérification de la structure"
echo "════════════════════════════════════════"
echo "Liste des tables:"
TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>&1)
if [ $? -eq 0 ]; then
    echo "$TABLES"
    TABLE_COUNT=$(echo "$TABLES" | wc -w)
    echo "Total: $TABLE_COUNT tables"
    echo -e "${GREEN}✓ Structure accessible${NC}"
else
    echo -e "${RED}✗ Impossible de lire la structure${NC}"
    echo "$TABLES"
fi
echo ""

echo -e "${BLUE}[5/8]${NC} Comptage des enregistrements"
echo "════════════════════════════════════════"
if [ -n "$TABLES" ]; then
    for table in $TABLES; do
        COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "  $table: $COUNT enregistrements"
        else
            echo -e "  ${YELLOW}$table: Erreur de lecture${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠ Aucune table détectée${NC}"
fi
echo ""

echo -e "${BLUE}[6/8]${NC} Vérification des clés étrangères"
echo "════════════════════════════════════════"
FOREIGN_KEY_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA foreign_key_check;" 2>&1)
if [ -z "$FOREIGN_KEY_CHECK" ]; then
    echo -e "${GREEN}✓ Clés étrangères: OK${NC}"
else
    echo -e "${RED}✗ Problèmes de clés étrangères détectés:${NC}"
    echo "$FOREIGN_KEY_CHECK"
fi
echo ""

echo -e "${BLUE}[7/8]${NC} Test de lecture/écriture"
echo "════════════════════════════════════════"
TEST_QUERY=$(sqlite3 "$DB_PATH" "SELECT 1;" 2>&1)
if [ "$TEST_QUERY" = "1" ]; then
    echo -e "${GREEN}✓ Lecture: OK${NC}"
else
    echo -e "${RED}✗ Lecture: ÉCHEC${NC}"
    echo "$TEST_QUERY"
fi
echo ""

echo -e "${BLUE}[8/8]${NC} Informations supplémentaires"
echo "════════════════════════════════════════"
echo "Version SQLite:"
sqlite3 --version

echo ""
echo "Configuration PRAGMA:"
sqlite3 "$DB_PATH" "PRAGMA page_size; PRAGMA page_count; PRAGMA freelist_count;" 2>/dev/null | paste -s -d' ' | awk '{print "Page size: " $1 " bytes, Pages: " $2 ", Free pages: " $3}'
echo ""

# Résumé et recommandations
echo -e "${CYAN}"
echo "════════════════════════════════════════════════════════════"
echo "RÉSUMÉ DU DIAGNOSTIC"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

if [ "$INTEGRITY_OK" = true ] && [ "$QUICK_CHECK" = "ok" ]; then
    echo -e "${GREEN}✓✓✓ BASE DE DONNÉES EN BON ÉTAT ✓✓✓${NC}"
    echo ""
    echo "La base de données SQLite est intègre et fonctionnelle."
    echo "Le message d'erreur du monitoring est probablement un faux positif."
    echo ""
    echo "Raisons possibles du faux positif:"
    echo "  1. Sortie formatée différemment (retour à la ligne)"
    echo "  2. Permissions insuffisantes lors de la vérification"
    echo "  3. Base temporairement verrouillée"
    echo ""
else
    echo -e "${RED}✗✗✗ PROBLÈME DÉTECTÉ DANS LA BASE ✗✗✗${NC}"
    echo ""
    echo -e "${YELLOW}ACTIONS RECOMMANDÉES:${NC}"
    echo ""
    echo "1. BACKUP IMMÉDIAT"
    echo "   sudo mkdir -p $BACKUP_DIR"
    echo "   sudo cp $DB_PATH $BACKUP_DIR/db.sqlite.backup.$(date +%Y%m%d_%H%M%S)"
    echo ""
    echo "2. TENTATIVE DE RÉPARATION"
    echo "   sudo ./repair_sqlite_db.sh"
    echo ""
    echo "3. SI ÉCHEC - RESTAURATION DEPUIS BACKUP"
    echo "   Restaurer depuis: /var/backups/baikal/"
    echo ""
    echo -e "${RED}IMPORTANT: Ne pas ignorer ce problème !${NC}"
    echo "Les données pourraient être corrompues."
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

# Proposer une action
if [ "$INTEGRITY_OK" = false ]; then
    read -p "Voulez-vous créer un backup de sécurité maintenant ? (o/n): " BACKUP_NOW
    if [ "$BACKUP_NOW" = "o" ]; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/db.sqlite.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$DB_PATH" "$BACKUP_FILE"
        echo -e "${GREEN}✓ Backup créé: $BACKUP_FILE${NC}"
        echo "  Taille: $(du -h "$BACKUP_FILE" | cut -f1)"
    fi
fi

echo ""
echo "Pour plus d'aide, consultez:"
echo "  - Documentation SQLite: https://www.sqlite.org/pragma.html"
echo "  - Script de réparation: ./repair_sqlite_db.sh"
echo ""
