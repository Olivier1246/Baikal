# Configuration des clients CalDAV/CardDAV

## URLs de connexion

### Format standard

- **CalDAV**: `https://votre-domaine.com/dav.php`
- **CardDAV**: `https://votre-domaine.com/dav.php`

### Auto-découverte

- **CalDAV**: `https://votre-domaine.com/.well-known/caldav`
- **CardDAV**: `https://votre-domaine.com/.well-known/carddav`

Remplacez `votre-domaine.com` par:
- `localhost` pour accès local
- Votre nom de domaine pour accès distant

## iOS / iPadOS

### Configuration CalDAV

1. Ouvrez **Réglages**
2. **Mots de passe et comptes** > **Ajouter un compte**
3. Sélectionnez **Autre**
4. **Ajouter un compte CalDAV**
5. Remplissez:
   - **Serveur**: `votre-domaine.com`
   - **Nom d'utilisateur**: votre nom d'utilisateur Baïkal
   - **Mot de passe**: votre mot de passe
   - **Description**: Calendriers Baïkal
6. **Suivant**
7. Activez **Calendriers**

### Configuration CardDAV

1. **Réglages** > **Mots de passe et comptes** > **Ajouter un compte**
2. **Autre** > **Ajouter un compte CardDAV**
3. Remplissez:
   - **Serveur**: `votre-domaine.com`
   - **Nom d'utilisateur**: votre nom d'utilisateur
   - **Mot de passe**: votre mot de passe
   - **Description**: Contacts Baïkal
4. **Suivant**
5. Activez **Contacts**

## Android

### DAVx⁵ (recommandé)

1. Installez **DAVx⁵** depuis [F-Droid](https://f-droid.org/) ou [Google Play](https://play.google.com/store/apps/details?id=at.bitfire.davdroid)
2. Ouvrez DAVx⁵
3. **+** (Ajouter un compte)
4. **Connexion avec URL et nom d'utilisateur**
5. Remplissez:
   - **URL de base**: `https://votre-domaine.com/dav.php`
   - **Nom d'utilisateur**: votre nom
   - **Mot de passe**: votre mot de passe
6. **Connexion**
7. Sélectionnez les calendriers et carnets d'adresses à synchroniser
8. **Créer un compte**
9. Donnez les permissions demandées

### Configuration synchronisation

Dans DAVx⁵:
- **Paramètres** > **Synchronisation**
- Activez la synchronisation automatique
- Choisissez l'intervalle (15 min, 1h, etc.)

## Thunderbird

### Lightning (Calendriers)

1. Ouvrez Thunderbird
2. **Fichier** > **Nouveau** > **Calendrier**
3. **Sur le réseau**
4. **Format**: CalDAV
5. **Emplacement**: `https://votre-domaine.com/dav.php/calendars/username/calendar-name/`
   
   Remplacez:
   - `username`: votre nom d'utilisateur
   - `calendar-name`: nom du calendrier

6. **Suivant**
7. Nom et couleur du calendrier
8. Entrez vos identifiants quand demandé

### CardBook (Contacts)

1. Installez l'extension **CardBook**
2. Ouvrez CardBook (bouton dans la barre)
3. **Carnet d'adresses** > **Nouveau carnet d'adresses distant**
4. **CardDAV**
5. Remplissez:
   - **URL**: `https://votre-domaine.com/dav.php/addressbooks/username/default/`
   - **Nom d'utilisateur**: votre nom
   - **Nom du carnet**: Contacts Baïkal
6. **Valider**
7. Entrez le mot de passe

## macOS

### Calendrier

1. Ouvrez **Calendrier**
2. **Calendrier** > **Ajouter un compte**
3. **Autre compte CalDAV**
4. Remplissez:
   - **Type de compte**: Automatique
   - **Adresse du serveur**: `votre-domaine.com`
   - **Nom d'utilisateur**: votre nom
   - **Mot de passe**: votre mot de passe
5. **Se connecter**

### Contacts

1. Ouvrez **Contacts**
2. **Contacts** > **Ajouter un compte**
3. **Autre compte CardDAV**
4. Remplissez:
   - **Type de compte**: Automatique
   - **Adresse du serveur**: `votre-domaine.com`
   - **Nom d'utilisateur**: votre nom
   - **Mot de passe**: votre mot de passe
5. **Se connecter**

## Windows

### Outlook avec CalDAV Synchronizer

1. Téléchargez [CalDAV Synchronizer](https://caldavsynchronizer.org/)
2. Installez l'extension
3. Dans Outlook: **CalDAV Synchronizer** > **Synchronization Profiles**
4. **Add new profile** > **Generic CalDAV/CardDAV**
5. Remplissez:
   - **DAV URL**: `https://votre-domaine.com/dav.php`
   - **Username**: votre nom
   - **Password**: votre mot de passe
6. **Test settings**
7. **OK**

## Linux

### Evolution

1. Ouvrez **Evolution**
2. **Fichier** > **Nouveau** > **Calendrier**
3. **Type**: CalDAV
4. Remplissez:
   - **URL**: `https://votre-domaine.com/dav.php/calendars/username/calendar-name/`
   - **Nom d'utilisateur**: votre nom
5. **Appliquer**

### GNOME Agenda

1. Ouvrez **Paramètres**
2. **Comptes en ligne**
3. **Ajouter un compte** > **Autre**
4. Entrez l'URL CalDAV

## Tests et vérification

### Test de connexion

Depuis un terminal:

```bash
curl -u username:password https://votre-domaine.com/dav.php/calendars/username/
```

Devrait retourner du XML avec la liste des calendriers.

### Vérifier synchronisation

1. Créez un événement sur un appareil
2. Attendez quelques secondes
3. Vérifiez qu'il apparaît sur les autres appareils
4. Modifiez l'événement sur un autre appareil
5. Vérifiez la modification sur tous les appareils

## Problèmes courants

### "Impossible de se connecter au serveur"

- Vérifiez l'URL (avec ou sans `/dav.php`)
- Vérifiez que HTTPS est configuré
- Testez avec `http://` si pas de certificat SSL

### "Nom d'utilisateur ou mot de passe incorrect"

- Vérifiez les identifiants dans l'interface web Baïkal
- Vérifiez les majuscules/minuscules
- Créez un nouveau mot de passe

### "Erreur SSL"

- Installez un certificat SSL valide
- Ou utilisez `http://` temporairement (non recommandé)

### Synchronisation lente

- Réduisez l'intervalle de synchronisation
- Vérifiez la connexion réseau
- Consultez les logs serveur

## Support

Consultez [TROUBLESHOOTING.md](TROUBLESHOOTING.md) pour plus d'aide.
