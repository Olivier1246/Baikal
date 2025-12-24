#!/bin/bash

################################################################################
# Diagnostic complet - Tous les principals et calendriers
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

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      DIAGNOSTIC COMPLET BASE DE DONNÉES BAÏKAL           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ============================================
# 1. TOUS les principals
# ============================================
echo -e "${BLUE}TOUS LES PRINCIPALS (utilisateurs):${NC}"
echo "════════════════════════════════════════"

PRINCIPALS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname, email FROM principals ORDER BY uri;" 2>/dev/null)

if [ -z "$PRINCIPALS" ]; then
    echo -e "${RED}✗ Aucun principal trouvé${NC}"
else
    echo "$PRINCIPALS" | while IFS='|' read -r uri displayname email; do
        echo ""
        echo -e "${GREEN}Principal URI: $uri${NC}"
        echo "  Nom: $displayname"
        if [ ! -z "$email" ]; then
            echo "  Email: $email"
        fi
        
        # Est-ce un utilisateur normal ?
        if [[ "$uri" == *"/users/"* ]]; then
            echo -e "  ${GREEN}Type: Utilisateur normal ✓${NC}"
        else
            echo -e "  ${YELLOW}Type: Principal non-standard ⚠${NC}"
            echo -e "  ${YELLOW}Devrait être: principals/users/[nom]/${NC}"
        fi
    done
fi

echo ""
echo ""

# ============================================
# 2. TOUS les calendriers
# ============================================
echo -e "${BLUE}TOUS LES CALENDRIERS:${NC}"
echo "════════════════════════════════════════"

CALENDARS=$(sqlite3 "$DB_PATH" "SELECT id, uri, displayname, principaluri, components FROM calendars ORDER BY id;" 2>/dev/null)

if [ -z "$CALENDARS" ]; then
    echo -e "${RED}✗ Aucun calendrier trouvé${NC}"
else
    echo "$CALENDARS" | while IFS='|' read -r id uri displayname principaluri components; do
        echo ""
        echo -e "${GREEN}📅 Calendrier ID $id${NC}"
        echo "  URI: $uri"
        echo "  Nom: $displayname"
        echo "  Principal: $principaluri"
        echo "  Composants: $components"
        
        # Extraire le nom d'utilisateur du principal
        if [[ "$principaluri" == *"/users/"* ]]; then
            username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
            echo -e "  ${GREEN}Utilisateur: $username${NC}"
        else
            username=$(echo "$principaluri" | sed 's|principals/||' | sed 's|/$||')
            echo -e "  ${YELLOW}Utilisateur (non-standard): $username ⚠${NC}"
        fi
        
        # Extraire l'URI du calendrier
        calname=$(echo "$uri" | sed 's|.*/calendars/||' | sed 's|/$||')
        echo "  Calendrier URI: $calname"
        
        # Construire l'URL CalDAV
        if [[ "$principaluri" == *"/users/"* ]]; then
            caldav_url="https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/"
        else
            # Pour les principals non-standard, essayer plusieurs variantes
            caldav_url1="https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/"
            caldav_url2="https://caldav.maison-oadf.ddns.net/dav.php/$uri"
            echo -e "  ${YELLOW}URL CalDAV possible 1: $caldav_url1${NC}"
            echo -e "  ${YELLOW}URL CalDAV possible 2: $caldav_url2${NC}"
            continue
        fi
        
        echo -e "  ${CYAN}URL CalDAV: $caldav_url${NC}"
        
        # Compter les événements
        event_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM calendarobjects WHERE calendarid=$id;" 2>/dev/null)
        echo "  Événements: $event_count"
    done
fi

echo ""
echo ""

# ============================================
# 3. TOUS les carnets d'adresses
# ============================================
echo -e "${BLUE}TOUS LES CARNETS D'ADRESSES:${NC}"
echo "════════════════════════════════════════"

ADDRESSBOOKS=$(sqlite3 "$DB_PATH" "SELECT id, uri, displayname, principaluri FROM addressbooks ORDER BY id;" 2>/dev/null)

if [ -z "$ADDRESSBOOKS" ]; then
    echo -e "${YELLOW}⚠ Aucun carnet d'adresses${NC}"
else
    echo "$ADDRESSBOOKS" | while IFS='|' read -r id uri displayname principaluri; do
        echo ""
        echo -e "${GREEN}📇 Carnet ID $id${NC}"
        echo "  URI: $uri"
        echo "  Nom: $displayname"
        echo "  Principal: $principaluri"
        
        # Extraire le nom d'utilisateur
        if [[ "$principaluri" == *"/users/"* ]]; then
            username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
            echo -e "  ${GREEN}Utilisateur: $username${NC}"
        else
            username=$(echo "$principaluri" | sed 's|principals/||' | sed 's|/$||')
            echo -e "  ${YELLOW}Utilisateur (non-standard): $username ⚠${NC}"
        fi
        
        bookname=$(echo "$uri" | sed 's|.*/addressbooks/||' | sed 's|/$||')
        echo "  Carnet URI: $bookname"
        
        # Construire l'URL CardDAV
        if [[ "$principaluri" == *"/users/"* ]]; then
            carddav_url="https://caldav.maison-oadf.ddns.net/dav.php/addressbooks/$username/$bookname/"
        else
            carddav_url1="https://caldav.maison-oadf.ddns.net/dav.php/addressbooks/$username/$bookname/"
            carddav_url2="https://caldav.maison-oadf.ddns.net/dav.php/$uri"
            echo -e "  ${YELLOW}URL CardDAV possible 1: $carddav_url1${NC}"
            echo -e "  ${YELLOW}URL CardDAV possible 2: $carddav_url2${NC}"
            continue
        fi
        
        echo -e "  ${CYAN}URL CardDAV: $carddav_url${NC}"
        
        # Compter les contacts
        card_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cards WHERE addressbookid=$id;" 2>/dev/null)
        echo "  Contacts: $card_count"
    done
fi

echo ""
echo ""

# ============================================
# DIAGNOSTIC ET RECOMMANDATIONS
# ============================================
echo -e "${CYAN}"
echo "════════════════════════════════════════════════════════════"
echo "DIAGNOSTIC"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Vérifier si on a des principals non-standard
NON_STANDARD=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM principals WHERE uri NOT LIKE '%/users/%' AND uri != 'principals/';" 2>/dev/null)

if [ "$NON_STANDARD" -gt 0 ]; then
    echo -e "${RED}⚠ PROBLÈME DÉTECTÉ: Utilisateur avec URI non-standard${NC}"
    echo ""
    echo "Baïkal a créé un utilisateur avec un chemin incorrect."
    echo "L'URI devrait être: principals/users/Olivier/"
    echo "Mais il est: principals/Olivier"
    echo ""
    echo -e "${YELLOW}SOLUTIONS:${NC}"
    echo ""
    echo "OPTION 1 (RECOMMANDÉE): Recréer l'utilisateur correctement"
    echo "  1. Aller sur https://caldav.maison-oadf.ddns.net/admin/"
    echo "  2. Supprimer l'utilisateur actuel (sauvegardez les données!)"
    echo "  3. Créer un nouvel utilisateur"
    echo "  4. Vérifier que l'URI est: principals/users/olivier/"
    echo ""
    echo "OPTION 2: Corriger dans la base de données (avancé)"
    echo "  sudo ./fix_principal_uri.sh"
    echo ""
    echo "OPTION 3: Tester les URLs alternatives ci-dessus"
    echo "  Certaines URLs peuvent fonctionner malgré l'URI non-standard"
    echo ""
fi

# Afficher les URLs à tester
echo -e "${CYAN}URLs À TESTER DANS THUNDERBIRD:${NC}"
echo ""

# Pour chaque calendrier, afficher toutes les variantes possibles
sqlite3 "$DB_PATH" "SELECT uri, principaluri FROM calendars;" 2>/dev/null | while IFS='|' read -r uri principaluri; do
    # Extraire le nom d'utilisateur
    if [[ "$principaluri" == *"/users/"* ]]; then
        username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
    else
        username=$(echo "$principaluri" | sed 's|principals/||' | sed 's|/$||')
    fi
    
    calname=$(echo "$uri" | sed 's|.*/calendars/||' | sed 's|/$||')
    
    echo "Calendrier: $calname"
    echo "  Variante 1: https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/"
    
    if [[ "$principaluri" != *"/users/"* ]]; then
        echo "  Variante 2: https://caldav.maison-oadf.ddns.net/dav.php/$uri"
        # Essayer avec principals dans l'URL
        echo "  Variante 3: https://caldav.maison-oadf.ddns.net/dav.php/principals/$username/calendars/$calname/"
    fi
    echo ""
done

echo "════════════════════════════════════════════════════════════"
echo ""

# Test avec curl
echo -e "${YELLOW}COMMANDES DE TEST:${NC}"
echo ""
echo "Testez chaque URL avec curl (remplacez password par votre mot de passe):"
echo ""

sqlite3 "$DB_PATH" "SELECT uri, principaluri FROM calendars;" 2>/dev/null | while IFS='|' read -r uri principaluri; do
    if [[ "$principaluri" == *"/users/"* ]]; then
        username=$(echo "$principaluri" | sed 's|.*/users/||' | sed 's|/$||')
    else
        username=$(echo "$principaluri" | sed 's|principals/||' | sed 's|/$||')
    fi
    
    calname=$(echo "$uri" | sed 's|.*/calendars/||' | sed 's|/$||')
    
    echo "# Test calendrier: $calname"
    echo "curl -u '$username:password' -X PROPFIND -H 'Depth: 1' \\"
    echo "  'https://caldav.maison-oadf.ddns.net/dav.php/calendars/$username/$calname/'"
    echo ""
done

echo "════════════════════════════════════════════════════════════"
