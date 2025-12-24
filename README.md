# 📅 Baïkal Installation Suite

Suite complète d'installation, de maintenance et de monitoring pour serveur **Baïkal CalDAV/CardDAV**.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange.svg)](https://www.debian.org/)

## 🎯 À propos

Cette suite d'outils permet d'installer, configurer et maintenir facilement un serveur Baïkal (CalDAV/CardDAV) sur Debian/Ubuntu. Elle inclut :

- ✅ Installation automatisée complète
- ✅ Configuration SSL avec Let's Encrypt
- ✅ Backups automatiques configurables
- ✅ Monitoring système complet
- ✅ Scripts de dépannage et réparation
- ✅ Documentation exhaustive

## 📋 Prérequis

- **Système** : Debian 10+ ou Ubuntu 20.04+
- **RAM** : 512 Mo minimum (1 Go recommandé)
- **Disque** : 1 Go minimum d'espace libre
- **Accès** : root (sudo)
- **Réseau** : Connexion Internet pour l'installation

## 🚀 Installation rapide

### 1. Cloner le dépôt

```bash
git clone https://github.com/Olivier1246/Baikal.git baikal-install
cd baikal-install
```

### 2. Rendre les scripts exécutables

```bash
chmod +x install/*.sh maintenance/*.sh troubleshoot/*.sh
```

### 3. Lancer l'installation

**Option A - Installation guidée (recommandée)**

```bash
sudo ./install/start.sh
```

**Option B - Installation directe**

```bash
# Vérifier les prérequis
sudo ./install/check_prereqs.sh

# Installer Baïkal
sudo ./install/baikal_install.sh

# Configurer SSL (optionnel, pour accès distant)
sudo ./install/setup_ssl.sh

# Configurer les backups
sudo ./maintenance/setup_backup.sh
```

### 4. Configuration web

Une fois l'installation terminée, ouvrez votre navigateur :

- **Local** : http://localhost/
- **Distant** : https://votre-domaine.com/

Suivez l'assistant de configuration pour créer le compte administrateur et configurer la base de données.

## 📁 Structure du projet

```
baikal-install-suite/
├── install/              # Scripts d'installation
│   ├── start.sh         # Menu interactif principal ⭐
│   ├── check_prereqs.sh # Vérification prérequis
│   ├── baikal_install.sh # Installation Baïkal
│   ├── setup_ssl.sh     # Configuration SSL/HTTPS
│   └── upgrade_php.sh   # Mise à jour PHP 8.2/8.3
│
├── maintenance/          # Maintenance et monitoring
│   ├── monitor.sh       # Monitoring système complet
│   ├── backup.sh        # Script de backup manuel
│   ├── setup_backup.sh  # Configuration backups auto
│   ├── update.sh        # Mise à jour Baïkal
│   └── check_updates.sh # Vérifier nouvelles versions
│
├── troubleshoot/         # Résolution de problèmes
│   ├── diagnose.sh      # Diagnostic complet système
│   ├── fix_permissions.sh # Correction permissions
│   ├── fix_database.sh  # Réparation base de données
│   └── fix_principals.sh # Correction URIs utilisateurs
│
├── docs/                 # Documentation
│   ├── INSTALL.md       # Guide d'installation détaillé
│   ├── CLIENTS.md       # Configuration clients (iOS, Android...)
│   ├── TROUBLESHOOTING.md # Guide de dépannage
│   ├── MYSQL.md         # Configuration MySQL avancée
│   └── SECURITY.md      # Bonnes pratiques sécurité
│
├── .gitignore
├── README.md            # Ce fichier
├── structure.txt        # Structure détaillée du projet
└── LICENSE
```

## 🎓 Guide d'utilisation

### Installation complète

```bash
# 1. Vérifier que le système est compatible
sudo ./install/check_prereqs.sh

# 2. Installer Baïkal (SQLite par défaut)
sudo ./install/baikal_install.sh

# 3. Configurer HTTPS (si accès distant)
sudo ./install/setup_ssl.sh

# 4. Activer les backups automatiques
sudo ./maintenance/setup_backup.sh
```

### Maintenance quotidienne

```bash
# Vérifier l'état du système
sudo ./maintenance/monitor.sh

# Créer un backup manuel
sudo ./maintenance/backup.sh

# Vérifier les mises à jour disponibles
sudo ./maintenance/check_updates.sh
```

### En cas de problème

```bash
# Diagnostic complet
sudo ./troubleshoot/diagnose.sh

# Corriger les permissions
sudo ./troubleshoot/fix_permissions.sh

# Réparer la base de données
sudo ./troubleshoot/fix_database.sh
```

## 📱 Configuration des clients

Baïkal est compatible avec tous les clients CalDAV/CardDAV standard :

- **iOS/iPadOS** : Configuration native dans Réglages
- **Android** : Via DAVx⁵ (recommandé)
- **Thunderbird** : Extension Lightning + CardBook
- **macOS** : Calendrier et Contacts natifs
- **Windows** : Outlook + CalDav Synchronizer ou eM Client
- **Linux** : Evolution, GNOME Calendar

➡️ Voir [docs/CLIENTS.md](docs/CLIENTS.md) pour les instructions détaillées.

## 🔧 Configuration

### Après installation

Les fichiers de configuration sont créés dans `/root/` :

```bash
/root/baikal_install_info.txt    # Informations d'installation
/root/baikal_ssl_info.txt        # Configuration SSL
/root/baikal_backup_config.txt   # Configuration backups
```

### Chemins importants

```bash
/var/www/baikal/                 # Installation Baïkal
├── Specific/                    # Données utilisateurs
│   ├── db/db.sqlite            # Base de données
│   └── logs/                   # Logs Baïkal
└── config/                      # Configuration

/etc/nginx/sites-available/baikal # Configuration Nginx
/var/backups/baikal/              # Backups automatiques
/var/log/nginx/baikal_*.log       # Logs Nginx
```

## 📊 Monitoring

Le script de monitoring vérifie :

- ✅ État des services (Nginx, PHP-FPM)
- ✅ Espace disque disponible
- ✅ Intégrité de la base de données
- ✅ Validité du certificat SSL
- ✅ Ancienneté des backups
- ✅ Permissions des fichiers
- ✅ Erreurs dans les logs

```bash
sudo ./maintenance/monitor.sh
```

## 🔐 Sécurité

### Recommandations essentielles

1. **Toujours utiliser HTTPS** pour l'accès distant
2. **Mots de passe forts** (12+ caractères)
3. **Backups réguliers** et testés
4. **Firewall activé** (ufw)
5. **Mises à jour système** automatiques

➡️ Voir [docs/SECURITY.md](docs/SECURITY.md) pour le guide complet.

## 🐛 Dépannage

### Problèmes courants

| Problème | Solution rapide |
|----------|----------------|
| Service inactif | `sudo systemctl restart nginx php*-fpm` |
| Erreur permissions | `sudo ./troubleshoot/fix_permissions.sh` |
| Base corrompue | `sudo ./troubleshoot/fix_database.sh` |
| Calendrier introuvable | Vérifier création dans admin Baïkal |

➡️ Voir [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) pour plus d'aide.

## 📚 Documentation

- [Guide d'installation détaillé](docs/INSTALL.md)
- [Configuration des clients](docs/CLIENTS.md)
- [Guide de dépannage](docs/TROUBLESHOOTING.md)
- [Configuration MySQL](docs/MYSQL.md)
- [Sécurité et bonnes pratiques](docs/SECURITY.md)

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

- Signaler des bugs
- Proposer des améliorations
- Soumettre des pull requests
- Améliorer la documentation

## 📝 Changelog

### Version 2.0 (2025-01-XX)

- Restructuration complète du projet
- Scripts modulaires et organisés
- Consolidation des outils de diagnostic
- Documentation améliorée
- Support PHP 8.2/8.3

### Version 1.0 (2024-12-XX)

- Première version publique
- Scripts d'installation de base
- Monitoring et backups

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- **Baïkal** : Net Gusto & fruux
- **sabre/dav** : Communauté sabre
- Scripts créés avec l'aide de **Claude (Anthropic)**

## 📞 Support

- **Documentation Baïkal** : https://sabre.io/baikal/
- **GitHub Issues** : https://github.com/Olivier1246/Baikal/issues
- **Communauté** : https://github.com/sabre-io/Baikal/discussions

---

**Bon calendrier ! 📅**
