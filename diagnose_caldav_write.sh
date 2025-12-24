#!/bin/bash

################################################################################
# Diagnostic des problèmes d'écriture CalDAV/CardDAV
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_PATH="/var/www/baikal/Specific/db/db.sqlite"
INSTALL_DIR="/var/www/baikal"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      DIAGNOSTIC PROBLÈMES D'ÉCRITURE CALDAV              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Erreur rencontrée: MODIFICATION_FAILED"
echo "Cela signifie que Thunderbird ne peut pas écrire dans le calendrier."
echo ""

PROBLEMS=0

# ============================================
# 1. Vérifier les permissions des fichiers
# ============================================
echo -e "${BLUE}[1/7]${NC} Vérification des permissions"
echo "════════════════════════════════════════"

# Specific/
if [ -d "$INSTALL_DIR/Specific" ]; then
    SPECIFIC_PERMS=$(stat -c %a "$INSTALL_DIR/Specific")
    SPECIFIC_OWNER=$(stat -c %U:%G "$INSTALL_DIR/Specific")
    
    echo "Specific/:"
    echo "  Permissions: $SPECIFIC_PERMS"
    echo "  Propriétaire: $SPECIFIC_OWNER"
    
    if [ "$SPECIFIC_PERMS" = "770" ] || [ "$SPECIFIC_PERMS" = "775" ]; then
        if [ "$SPECIFIC_OWNER" = "www-data:www-data" ]; then
            echo -e "  ${GREEN}✓ OK${NC}"
        else
            echo -e "  ${RED}✗ Mauvais propriétaire (devrait être www-data:www-data)${NC}"
            ((PROBLEMS++))
        fi
    else
        echo -e "  ${YELLOW}⚠ Permissions non optimales (recommandé: 770)${NC}"
    fi
fi

# db/
if [ -d "$INSTALL_DIR/Specific/db" ]; then
    DB_DIR_PERMS=$(stat -c %a "$INSTALL_DIR/Specific/db")
    DB_DIR_OWNER=$(stat -c %U:%G "$INSTALL_DIR/Specific/db")
    
    echo "Specific/db/:"
    echo "  Permissions: $DB_DIR_PERMS"
    echo "  Propriétaire: $DB_DIR_OWNER"
    
    if [ "$DB_DIR_OWNER" = "www-data:www-data" ]; then
        echo -e "  ${GREEN}✓ OK${NC}"
    else
        echo -e "  ${RED}✗ Mauvais propriétaire${NC}"
        ((PROBLEMS++))
    fi
fi

# db.sqlite
if [ -f "$DB_PATH" ]; then
    DB_PERMS=$(stat -c %a "$DB_PATH")
    DB_OWNER=$(stat -c %U:%G "$DB_PATH")
    
    echo "db.sqlite:"
    echo "  Permissions: $DB_PERMS"
    echo "  Propriétaire: $DB_OWNER"
    
    if [ "$DB_OWNER" = "www-data:www-data" ]; then
        if [ "$DB_PERMS" = "660" ] || [ "$DB_PERMS" = "664" ] || [ "$DB_PERMS" = "770" ]; then
            echo -e "  ${GREEN}✓ OK${NC}"
        else
            echo -e "  ${YELLOW}⚠ Permissions inhabituelles${NC}"
        fi
    else
        echo -e "  ${RED}✗ Mauvais propriétaire${NC}"
        ((PROBLEMS++))
    fi
fi

echo ""

# ============================================
# 2. Vérifier que la base est accessible en écriture
# ============================================
echo -e "${BLUE}[2/7]${NC} Test d'écriture sur la base de données"
echo "════════════════════════════════════════"

# Tester si on peut écrire
TEST_WRITE=$(sudo -u www-data sqlite3 "$DB_PATH" "SELECT 1;" 2>&1)

if [ "$TEST_WRITE" = "1" ]; then
    echo -e "${GREEN}✓ Base accessible en écriture par www-data${NC}"
else
    echo -e "${RED}✗ Base NON accessible en écriture${NC}"
    echo "Erreur: $TEST_WRITE"
    ((PROBLEMS++))
fi

echo ""

# ============================================
# 3. Vérifier les calendriers dans la base
# ============================================
echo -e "${BLUE}[3/7]${NC} Vérification des calendriers"
echo "════════════════════════════════════════"

CALENDARS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname FROM calendars;" 2>/dev/null)

if [ -z "$CALENDARS" ]; then
    echo -e "${YELLOW}⚠ Aucun calendrier trouvé dans la base${NC}"
    echo "  Créez un calendrier dans l'interface admin de Baïkal"
    ((PROBLEMS++))
else
    echo "Calendriers trouvés:"
    echo "$CALENDARS" | while IFS='|' read -r uri name; do
        echo "  - URI: $uri"
        echo "    Nom: $name"
    done
    echo -e "${GREEN}✓ Calendriers présents${NC}"
fi

echo ""

# ============================================
# 4. Vérifier les utilisateurs et leurs droits
# ============================================
echo -e "${BLUE}[4/7]${NC} Vérification des utilisateurs"
echo "════════════════════════════════════════"

USERS=$(sqlite3 "$DB_PATH" "SELECT uri, displayname FROM principals WHERE uri LIKE '%/users/%';" 2>/dev/null)

if [ -z "$USERS" ]; then
    echo -e "${RED}✗ Aucun utilisateur trouvé${NC}"
    ((PROBLEMS++))
else
    echo "Utilisateurs:"
    echo "$USERS" | while IFS='|' read -r uri name; do
        echo "  - URI: $uri"
        echo "    Nom: $name"
    done
    echo -e "${GREEN}✓ Utilisateurs présents${NC}"
fi

echo ""

# ============================================
# 5. Vérifier les logs Nginx
# ============================================
echo -e "${BLUE}[5/7]${NC} Vérification des logs récents"
echo "════════════════════════════════════════"

if [ -f "/var/log/nginx/baikal_error.log" ]; then
    RECENT_ERRORS=$(tail -20 /var/log/nginx/baikal_error.log | grep -i "caldav\|carddav\|403\|500" || echo "")
    
    if [ -z "$RECENT_ERRORS" ]; then
        echo -e "${GREEN}✓ Aucune erreur CalDAV récente dans les logs${NC}"
    else
        echo -e "${YELLOW}⚠ Erreurs récentes détectées:${NC}"
        echo "$RECENT_ERRORS" | head -5
    fi
else
    echo -e "${YELLOW}⚠ Fichier de log introuvable${NC}"
fi

echo ""

# ============================================
# 6. Vérifier la configuration PHP
# ============================================
echo -e "${BLUE}[6/7]${NC} Vérification de la configuration PHP"
echo "════════════════════════════════════════"

# Trouver la version PHP active
PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

if [ -f "$PHP_INI" ]; then
    UPLOAD_MAX=$(grep "^upload_max_filesize" "$PHP_INI" | cut -d'=' -f2 | xargs)
    POST_MAX=$(grep "^post_max_size" "$PHP_INI" | cut -d'=' -f2 | xargs)
    MEMORY=$(grep "^memory_limit" "$PHP_INI" | cut -d'=' -f2 | xargs)
    
    echo "Limites PHP:"
    echo "  upload_max_filesize: $UPLOAD_MAX"
    echo "  post_max_size: $POST_MAX"
    echo "  memory_limit: $MEMORY"
    
    echo -e "${GREEN}✓ Configuration PHP chargée${NC}"
else
    echo -e "${YELLOW}⚠ php.ini introuvable${NC}"
fi

echo ""

# ============================================
# 7. Test d'accès CalDAV
# ============================================
echo -e "${BLUE}[7/7]${NC} Test d'accès CalDAV"
echo "════════════════════════════════════════"

DOMAIN=$(grep "server_name" /etc/nginx/sites-available/baikal | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')

if [ ! -z "$DOMAIN" ]; then
    echo "Test d'accès à: https://$DOMAIN/dav.php"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$DOMAIN/dav.php" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "401" ]; then
        echo -e "${GREEN}✓ Serveur CalDAV répond (401 = authentification requise, normal)${NC}"
    elif [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Serveur CalDAV répond${NC}"
    else
        echo -e "${YELLOW}⚠ Code HTTP inattendu: $HTTP_CODE${NC}"
    fi
fi

echo ""

# ============================================
# RÉSUMÉ ET RECOMMANDATIONS
# ============================================
echo -e "${CYAN}"
echo "════════════════════════════════════════════════════════════"
echo "RÉSUMÉ DU DIAGNOSTIC"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

if [ $PROBLEMS -eq 0 ]; then
    echo -e "${GREEN}✓ Aucun problème côté serveur détecté${NC}"
    echo ""
    echo "Le problème vient probablement de la configuration Thunderbird."
    echo ""
    echo -e "${YELLOW}SOLUTIONS À ESSAYER:${NC}"
    echo ""
    echo "1. VÉRIFIER L'URL DU CALENDRIER"
    echo "   L'URL doit être au format:"
    echo "   https://caldav.maison-oadf.ddns.net/dav.php/calendars/[utilisateur]/[calendrier]/"
    echo ""
    echo "2. RECRÉER LE CALENDRIER DANS THUNDERBIRD"
    echo "   - Supprimer le calendrier existant"
    echo "   - Ajouter un nouveau calendrier réseau"
    echo "   - Sélectionner 'Sur le réseau' > CalDAV"
    echo "   - Entrer l'URL complète du calendrier"
    echo "   - Vérifier 'Lecture et écriture'"
    echo ""
    echo "3. VIDER LE CACHE THUNDERBIRD"
    echo "   - Fermer Thunderbird"
    echo "   - Supprimer le dossier cache"
    echo "   - Relancer Thunderbird"
    echo ""
    echo "4. TESTER AVEC CURL (commande fournie ci-dessous)"
    echo ""
else
    echo -e "${RED}✗ $PROBLEMS problème(s) détecté(s) côté serveur${NC}"
    echo ""
    echo -e "${YELLOW}CORRECTION AUTOMATIQUE:${NC}"
    echo "  sudo ./fix_caldav_permissions.sh"
    echo ""
fi

# Afficher la commande de test
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}COMMANDE DE TEST CALDAV${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Pour tester si CalDAV fonctionne avec curl:"
echo ""
echo "curl -u 'utilisateur:motdepasse' -X PROPFIND \\"
echo "  -H 'Depth: 1' \\"
echo "  https://$DOMAIN/dav.php/calendars/utilisateur/default/"
echo ""
echo "Remplacez 'utilisateur' et 'motdepasse' par vos identifiants Baïkal"
echo ""
echo "Si ça fonctionne, vous verrez du XML avec la liste des événements."
echo "Si ça échoue, vous verrez une erreur d'authentification ou de permissions."
echo ""
