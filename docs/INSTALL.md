# Guide d'installation Baïkal

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation rapide](#installation-rapide)
3. [Installation détaillée](#installation-détaillée)
4. [Configuration web](#configuration-web)
5. [Vérification](#vérification)

## Prérequis

### Système

- **OS**: Debian 10+ ou Ubuntu 20.04+
- **RAM**: 512 Mo minimum, 1 Go recommandé
- **Disque**: 1 Go d'espace libre minimum
- **Privilèges**: Accès root (sudo)

### Réseau

- Connexion Internet active
- Ports 80 et 443 disponibles
- Nom de domaine (optionnel, pour accès distant)

### Logiciels

Ces dépendances seront installées automatiquement:
- Nginx
- PHP 8.2+ (avec extensions: curl, mbstring, xml, zip, sqlite3, gd, intl)
- SQLite ou MySQL
- Certbot (pour SSL)

## Installation rapide

### Option 1: Menu interactif (recommandé)

```bash
git clone https://github.com/Olivier1246/Baikal.git
cd Baikal
sudo ./install/start.sh
```

Sélectionnez l'option 2 "Installation complète" et suivez les instructions.

### Option 2: Installation directe

```bash
sudo ./install/check_prereqs.sh
sudo ./install/baikal_install.sh
```

## Installation détaillée

### Étape 1: Vérification prérequis

```bash
sudo ./install/check_prereqs.sh
```

Ce script vérifie:
- ✓ Privilèges root
- ✓ Distribution Linux
- ✓ Espace disque et RAM
- ✓ Connectivité Internet
- ✓ Disponibilité des ports
- ✓ Services conflictuels

### Étape 2: Installation

```bash
sudo ./install/baikal_install.sh
```

Le script va vous demander:
1. **Nom de domaine** (laisser vide pour localhost)
2. **Type de base de données**:
   - SQLite (recommandé pour 1-10 utilisateurs)
   - MySQL (pour usage intensif)

#### Configuration SQLite (recommandé)

```
Nom de domaine: [Entrée]
Type de base: sqlite
```

#### Configuration MySQL

```
Nom de domaine: cal.example.com
Type de base: mysql
Nom base: baikal
Utilisateur: baikal
Mot de passe: ********
```

### Étape 3: Processus d'installation

L'installation va:

1. Mettre à jour le système
2. Installer PHP 8.2+ et extensions
3. Installer Nginx
4. Installer MySQL (si choisi)
5. Télécharger Baïkal depuis GitHub
6. Configurer Nginx
7. Configurer les permissions
8. Redémarrer les services

Durée: 5-10 minutes selon la connexion Internet.

## Configuration web

### Première connexion

1. Ouvrez votre navigateur:
   - Local: `http://localhost/`
   - Distant: `http://votre-domaine.com/`

2. Suivez l'assistant de configuration:

#### Écran 1: Système

- **Timezone**: Sélectionnez votre fuseau horaire
- **Base de données**:
  - SQLite: Déjà configuré
  - MySQL: Entrez les informations fournies lors de l'installation
- Cliquez "Sauvegarder les changements"

#### Écran 2: Administrateur

- **Nom d'utilisateur**: admin (par exemple)
- **Nom d'affichage**: Administrateur
- **Email**: votre@email.com
- **Mot de passe**: Choisissez un mot de passe fort
- Cliquez "Sauvegarder les changements"

### Créer un utilisateur

1. Connectez-vous avec le compte admin
2. Allez dans "Utilisateurs et droits"
3. Cliquez "Ajouter un utilisateur"
4. Remplissez:
   - Nom d'utilisateur
   - Nom d'affichage
   - Email
   - Mot de passe
5. Cliquez "Sauvegarder"

### Créer un calendrier

1. Sélectionnez l'utilisateur
2. Cliquez "Ajouter un calendrier"
3. Remplissez:
   - Nom du calendrier
   - Description (optionnel)
   - Couleur
4. Cliquez "Sauvegarder"

## Vérification

### Vérifier l'installation

```bash
sudo ./maintenance/monitor.sh
```

Ce script affiche l'état:
- ✓ Services (Nginx, PHP-FPM)
- ✓ Espace disque
- ✓ Base de données
- ✓ Certificat SSL (si configuré)

### Tester la connectivité

```bash
curl -I http://localhost/
```

Devrait retourner: `HTTP/1.1 200 OK`

### Vérifier les logs

```bash
# Logs Nginx
sudo tail -f /var/log/nginx/baikal_access.log
sudo tail -f /var/log/nginx/baikal_error.log

# Logs PHP
sudo tail -f /var/log/php*-fpm.log
```

## Prochaines étapes

1. **Configuration SSL** (si accès distant):
   ```bash
   sudo ./install/setup_ssl.sh
   ```

2. **Configuration backups**:
   ```bash
   sudo ./maintenance/setup_backup.sh
   ```

3. **Configuration clients**: Consultez [CLIENTS.md](CLIENTS.md)

## Résolution de problèmes

Si l'installation échoue:

```bash
# Diagnostic complet
sudo ./troubleshoot/diagnose.sh

# Vérifier les logs
sudo journalctl -xe
sudo tail -100 /var/log/nginx/baikal_error.log
```

Consultez [TROUBLESHOOTING.md](TROUBLESHOOTING.md) pour plus d'aide.

## Fichiers importants

Après installation, ces fichiers contiennent des informations utiles:

- `/root/baikal_install_info.txt` - Résumé installation
- `/root/baikal_ssl_info.txt` - Infos SSL (si configuré)
- `/root/baikal_backup_config.txt` - Infos backups (si configuré)

## Désinstallation

```bash
sudo systemctl stop nginx php*-fpm
sudo rm -rf /var/www/baikal
sudo rm /etc/nginx/sites-available/baikal
sudo rm /etc/nginx/sites-enabled/baikal
sudo apt remove --purge nginx php*
```
