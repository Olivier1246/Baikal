#!/bin/bash

################################################################################
# Liste des utilisateurs et calendriers Baïkal
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_PATH="/var/www/baikal/Specific/db/db.sqlite"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} Base de données introuvable: $DB_PATH"
    exit 1
fi

if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} sqlite3 n'est pas installé"
    echo "Installez-le avec: sudo apt install sqlite3"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      LISTE DES UTILISATEURS ET CALENDRIERS BAÏKAL        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ============================================
# 1. Liste des utilisateurs
# ============================================
echo -e "${BLUE}UTILISATEURS BAÏKAL:${NC}"
echo "════════════════════════════════════════"

USERS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname FROM principals WHERE uri LIKE '%/users/%' ORDER BY uri;" 2>/dev/null)

if [ -z "$USERS" ]; then
    echo -e "${RED}✗ Aucun utilisateur trouvé${NC}"
    echo ""
    echo "Créez un utilisateur dans l'interface admin:"
    echo "  https://caldav.maison-oadf.ddns.net/admin/"
else
    echo "$USERS" | while IFS='|' read -r uri displayname; do
        # Extraire le nom d'utilisateur de l'URI
        username=$(echo "$uri" | sed 's|.*/users/||' | sed 's|/$||')
        echo ""
        echo -e "${GREEN}Utilisateur: $username${NC}"
        echo "  Nom complet: $displayname"
        echo "  URI: $uri"
        
        # Compter les calendriers de cet utilisateur
        cal_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM calendars WHERE principaluri='$uri';" 2>/dev/null)
        echo "  Calendriers: $cal_count"
    done
fi

echo ""
echo ""

# ============================================
# 2. Liste des calendriers
# ============================================
echo -e "${BLUE}CALENDRIERS CALDAV:${NC}"
echo "════════════════════════════════════════"

CALENDARS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname, principaluri FROM calendars ORDER BY principaluri, uri;" 2>/dev/null)

if [ -z "$CALENDARS" ]; then
    echo -e "${RED}✗ Aucun calendrier trouvé${NC}"
    echo ""
    echo "Les calendriers doivent être créés dans l'interface admin de Baïkal."
else
    current_user=""
    echo "$CALENDARS" | while IFS='|' read -r uri displayname principaluri; do
        # Extraire le nom d'utilisateur
        username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
        
        if [ "$username" != "$current_user" ]; then
            echo ""
            echo -e "${YELLOW}═══ Utilisateur: $username ═══${NC}"
            current_user="$username"
        fi
        
        # Extraire le nom du calendrier de l'URI
        calname=$(echo "$uri" | sed 's|.*/calendars/||' | sed 's|/$||')
        
        echo ""
        echo -e "${GREEN}  📅 Calendrier: $calname${NC}"
        echo "     Nom: $displayname"
        
        # Composer l'URL complète
        full_url="https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/"
        echo -e "     ${CYAN}URL CalDAV: $full_url${NC}"
        
        # Compter les événements
        event_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM calendarobjects WHERE calendarid=(SELECT id FROM calendars WHERE uri='$uri');" 2>/dev/null)
        echo "     Événements: $event_count"
    done
fi

echo ""
echo ""

# ============================================
# 3. Liste des carnets d'adresses
# ============================================
echo -e "${BLUE}CARNETS D'ADRESSES CARDDAV:${NC}"
echo "════════════════════════════════════════"

ADDRESSBOOKS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname, principaluri FROM addressbooks ORDER BY principaluri, uri;" 2>/dev/null)

if [ -z "$ADDRESSBOOKS" ]; then
    echo -e "${YELLOW}⚠ Aucun carnet d'adresses trouvé${NC}"
else
    current_user=""
    echo "$ADDRESSBOOKS" | while IFS='|' read -r uri displayname principaluri; do
        username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
        
        if [ "$username" != "$current_user" ]; then
            echo ""
            echo -e "${YELLOW}═══ Utilisateur: $username ═══${NC}"
            current_user="$username"
        fi
        
        bookname=$(echo "$uri" | sed 's|.*/addressbooks/||' | sed 's|/$||')
        
        echo ""
        echo -e "${GREEN}  📇 Carnet: $bookname${NC}"
        echo "     Nom: $displayname"
        
        full_url="https://caldav.maison-oadf.ddns.net/dav.php/addressbooks/$username/$bookname/"
        echo -e "     ${CYAN}URL CardDAV: $full_url${NC}"
        
        # Compter les contacts
        card_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cards WHERE addressbookid=(SELECT id FROM addressbooks WHERE uri='$uri');" 2>/dev/null)
        echo "     Contacts: $card_count"
    done
fi

echo ""
echo ""

# ============================================
# RÉSUMÉ ET RECOMMANDATIONS
# ============================================
echo -e "${CYAN}"
echo "════════════════════════════════════════════════════════════"
echo "RÉSUMÉ"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

USER_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM principals WHERE uri LIKE '%/users/%';" 2>/dev/null)
CAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM calendars;" 2>/dev/null)
ADDR_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM addressbooks;" 2>/dev/null)

echo "Total utilisateurs: $USER_COUNT"
echo "Total calendriers: $CAL_COUNT"
echo "Total carnets d'adresses: $ADDR_COUNT"
echo ""

if [ "$CAL_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ AUCUN CALENDRIER CRÉÉ !${NC}"
    echo ""
    echo "Pour créer un calendrier:"
    echo "  1. Aller sur https://caldav.maison-oadf.ddns.net/admin/"
    echo "  2. Cliquer sur 'Utilisateurs & Ressources'"
    echo "  3. Cliquer sur votre utilisateur"
    echo "  4. Dans la section 'Calendriers', cliquer sur '+ Ajouter un calendrier'"
    echo "  5. Entrer un nom (ex: 'default' ou 'personnel')"
    echo "  6. Sauvegarder"
    echo ""
fi

echo "Interface admin Baïkal:"
echo "  https://caldav.maison-oadf.ddns.net/admin/"
echo ""

# Afficher les URLs à utiliser
if [ ! -z "$CALENDARS" ]; then
    echo -e "${GREEN}URLs à utiliser dans Thunderbird:${NC}"
    echo ""
    sqlite3 "$DB_PATH" "SELECT uri, principaluri FROM calendars;" 2>/dev/null | while IFS='|' read -r uri principaluri; do
        username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
        calname=$(echo "$uri" | sed 's|.*/calendars/||' | sed 's|/$||')
        echo "  https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/"
    done
    echo ""
fi

echo "════════════════════════════════════════════════════════════"
echo ""
