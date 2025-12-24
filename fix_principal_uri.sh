#!/bin/bash

################################################################################
# Correction de l'URI du principal pour un utilisateur Baïkal
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_PATH="/var/www/baikal/Specific/db/db.sqlite"
BACKUP_DIR="/var/backups/baikal/db_fix"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      CORRECTION URI PRINCIPAL BAÏKAL                     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Ce script corrige les URIs de principals créés de manière incorrecte."
echo "Exemple: principals/Olivier → principals/users/olivier/"
echo ""

# Vérifier les principals non-standard
NON_STANDARD=$(sqlite3 "$DB_PATH" "SELECT uri, displayname FROM principals WHERE uri NOT LIKE '%/users/%' AND uri != 'principals/';" 2>/dev/null)

if [ -z "$NON_STANDARD" ]; then
    echo -e "${GREEN}✓ Aucun principal non-standard détecté${NC}"
    echo "Tous les utilisateurs ont des URIs correctes."
    exit 0
fi

echo -e "${YELLOW}Principals non-standard détectés:${NC}"
echo ""
echo "$NON_STANDARD" | while IFS='|' read -r uri displayname; do
    echo "  URI: $uri"
    echo "  Nom: $displayname"
    echo ""
done

echo -e "${RED}⚠ ATTENTION ⚠${NC}"
echo "Cette opération va modifier directement la base de données."
echo "Un backup sera créé avant toute modification."
echo ""

read -p "Voulez-vous continuer ? (o/n): " CONFIRM
if [ "$CONFIRM" != "o" ]; then
    echo "Annulation"
    exit 0
fi

# Créer le backup
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/db.sqlite.before_fix_principal.$(date +%Y%m%d_%H%M%S)"

echo ""
echo -e "${BLUE}[1/5]${NC} Création du backup..."
cp "$DB_PATH" "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup créé: $BACKUP_FILE${NC}"
else
    echo -e "${RED}✗ Échec du backup${NC}"
    exit 1
fi

# Arrêter les services
echo ""
echo -e "${BLUE}[2/5]${NC} Arrêt des services..."
systemctl stop nginx
systemctl stop php*-fpm
echo -e "${GREEN}✓ Services arrêtés${NC}"

# Pour chaque principal non-standard
echo ""
echo -e "${BLUE}[3/5]${NC} Correction des URIs..."
echo ""

echo "$NON_STANDARD" | while IFS='|' read -r old_uri displayname; do
    # Extraire le nom d'utilisateur
    username=$(echo "$old_uri" | sed 's|principals/||' | sed 's|/$||')
    
    # Créer le nouvel URI (en minuscules pour éviter les problèmes)
    username_lower=$(echo "$username" | tr '[:upper:]' '[:lower:]')
    new_uri="principals/users/${username_lower}/"
    
    echo -e "${YELLOW}Correction de: $old_uri${NC}"
    echo "  → Nouvel URI: $new_uri"
    
    # Mettre à jour la table principals
    sqlite3 "$DB_PATH" "UPDATE principals SET uri='$new_uri' WHERE uri='$old_uri';"
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Principal mis à jour${NC}"
    else
        echo -e "  ${RED}✗ Échec de la mise à jour du principal${NC}"
        continue
    fi
    
    # Mettre à jour les calendriers associés
    CAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM calendars WHERE principaluri='$old_uri';" 2>/dev/null)
    if [ "$CAL_COUNT" -gt 0 ]; then
        sqlite3 "$DB_PATH" "UPDATE calendars SET principaluri='$new_uri' WHERE principaluri='$old_uri';"
        echo -e "  ${GREEN}✓ $CAL_COUNT calendrier(s) mis à jour${NC}"
        
        # Mettre à jour les URIs des calendriers
        CALENDARS=$(sqlite3 "$DB_PATH" "SELECT id, uri FROM calendars WHERE principaluri='$new_uri';" 2>/dev/null)
        echo "$CALENDARS" | while IFS='|' read -r cal_id cal_uri; do
            # Reconstruire l'URI du calendrier
            cal_name=$(echo "$cal_uri" | sed 's|.*/calendars/||' | sed 's|/$||')
            new_cal_uri="calendars/${username_lower}/${cal_name}/"
            
            sqlite3 "$DB_PATH" "UPDATE calendars SET uri='$new_cal_uri' WHERE id=$cal_id;"
            echo "    Calendrier $cal_id: $new_cal_uri"
        done
    fi
    
    # Mettre à jour les carnets d'adresses
    ADDR_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM addressbooks WHERE principaluri='$old_uri';" 2>/dev/null)
    if [ "$ADDR_COUNT" -gt 0 ]; then
        sqlite3 "$DB_PATH" "UPDATE addressbooks SET principaluri='$new_uri' WHERE principaluri='$old_uri';"
        echo -e "  ${GREEN}✓ $ADDR_COUNT carnet(s) d'adresses mis à jour${NC}"
        
        # Mettre à jour les URIs des carnets
        ADDRESSBOOKS=$(sqlite3 "$DB_PATH" "SELECT id, uri FROM addressbooks WHERE principaluri='$new_uri';" 2>/dev/null)
        echo "$ADDRESSBOOKS" | while IFS='|' read -r addr_id addr_uri; do
            addr_name=$(echo "$addr_uri" | sed 's|.*/addressbooks/||' | sed 's|/$||')
            new_addr_uri="addressbooks/${username_lower}/${addr_name}/"
            
            sqlite3 "$DB_PATH" "UPDATE addressbooks SET uri='$new_addr_uri' WHERE id=$addr_id;"
            echo "    Carnet $addr_id: $new_addr_uri"
        done
    fi
    
    echo ""
done

# Vérifier l'intégrité
echo ""
echo -e "${BLUE}[4/5]${NC} Vérification de la base..."
INTEGRITY=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>&1)

if [ "$INTEGRITY" = "ok" ]; then
    echo -e "${GREEN}✓ Base de données intègre${NC}"
else
    echo -e "${RED}✗ Problème d'intégrité détecté !${NC}"
    echo "Restauration du backup..."
    cp "$BACKUP_FILE" "$DB_PATH"
    chown www-data:www-data "$DB_PATH"
    chmod 660 "$DB_PATH"
    systemctl start php*-fpm
    systemctl start nginx
    echo -e "${RED}Base restaurée depuis le backup${NC}"
    exit 1
fi

# Restaurer les permissions
chown www-data:www-data "$DB_PATH"
chmod 660 "$DB_PATH"

# Redémarrer les services
echo ""
echo -e "${BLUE}[5/5]${NC} Redémarrage des services..."
systemctl start php*-fpm
systemctl start nginx

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Services redémarrés${NC}"
else
    echo -e "${RED}✗ Problème au démarrage de Nginx${NC}"
fi

# Afficher le résultat
echo ""
echo -e "${GREEN}"
echo "════════════════════════════════════════════════════════════"
echo "✓✓✓ CORRECTION TERMINÉE ✓✓✓"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

echo "Vérification des nouveaux URIs:"
echo ""

USERS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname FROM principals WHERE uri LIKE '%/users/%' ORDER BY uri;" 2>/dev/null)

if [ -z "$USERS" ]; then
    echo -e "${RED}✗ Aucun utilisateur trouvé${NC}"
else
    echo "$USERS" | while IFS='|' read -r uri displayname; do
        username=$(echo "$uri" | sed 's|.*/users/||' | sed 's|/$||')
        echo -e "${GREEN}Utilisateur: $username${NC}"
        echo "  URI: $uri"
        echo "  Nom: $displayname"
        
        # Afficher les calendriers
        CALS=$(sqlite3 "$DB_PATH" "SELECT uri FROM calendars WHERE principaluri='$uri';" 2>/dev/null)
        if [ ! -z "$CALS" ]; then
            echo "  Calendriers:"
            echo "$CALS" | while read cal_uri; do
                cal_name=$(echo "$cal_uri" | sed 's|.*/calendars/||' | sed 's|/$||')
                full_url="https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$cal_name/"
                echo -e "    ${CYAN}$full_url${NC}"
            done
        fi
        echo ""
    done
fi

echo ""
echo "Backup disponible: $BACKUP_FILE"
echo ""
echo "Nouvelles URLs à utiliser dans Thunderbird listées ci-dessus !"
echo ""
