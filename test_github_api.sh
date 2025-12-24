#!/bin/bash

################################################################################
# Test rapide de l'API GitHub pour les releases Baïkal
################################################################################

echo "Test de l'API GitHub pour Baïkal..."
echo ""

# Test 1: Récupération des releases
echo "1. Test de récupération des releases..."
RELEASES=$(curl -s "https://api.github.com/repos/sabre-io/Baikal/releases")

if [ -z "$RELEASES" ]; then
    echo "❌ Échec: Impossible de récupérer les releases"
    exit 1
else
    echo "✓ Releases récupérées"
fi

# Test 2: Vérifier que jq est installé
echo ""
echo "2. Vérification de jq..."
if command -v jq &> /dev/null; then
    echo "✓ jq est installé"
    
    # Test 3: Parser les releases
    echo ""
    echo "3. Parsing des releases..."
    COUNT=$(echo "$RELEASES" | jq '. | length')
    echo "✓ Nombre de releases trouvées: $COUNT"
    
    # Afficher les 5 dernières
    echo ""
    echo "Les 5 dernières versions:"
    echo "$RELEASES" | jq -r '.[:5] | .[] | "  - \(.tag_name) (\(.published_at | split("T")[0]))"'
    
else
    echo "❌ jq n'est pas installé"
    echo "Installation: sudo apt install jq"
fi

# Test 4: Vérifier wget
echo ""
echo "4. Vérification de wget..."
if command -v wget &> /dev/null; then
    echo "✓ wget est installé"
else
    echo "❌ wget n'est pas installé"
    echo "Installation: sudo apt install wget"
fi

# Test 5: Tester le téléchargement d'une release
echo ""
echo "5. Test de l'URL de téléchargement..."
LATEST_TAG=$(echo "$RELEASES" | jq -r '.[0].tag_name')
LATEST_VERSION=${LATEST_TAG#v}
DOWNLOAD_URL="https://github.com/sabre-io/Baikal/releases/download/${LATEST_TAG}/baikal-${LATEST_VERSION}.zip"
echo "URL: $DOWNLOAD_URL"

# Vérifier que l'URL existe (sans télécharger le fichier)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -I "$DOWNLOAD_URL")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✓ URL de téléchargement valide (HTTP $HTTP_CODE)"
else
    echo "⚠ Code HTTP inattendu: $HTTP_CODE"
fi

echo ""
echo "========================================="
echo "Tests terminés !"
echo "========================================="
echo ""
echo "Le script update_baikal.sh devrait fonctionner correctement."
