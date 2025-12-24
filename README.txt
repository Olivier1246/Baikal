################################################################################
#                                                                              #
#                    INSTALLATION BAÏKAL - SERVEUR CALDAV/CARDAV               #
#                                                                              #
################################################################################

Ce projet contient un ensemble complet de scripts pour installer, configurer,
et maintenir un serveur Baïkal (CalDAV/CardDAV) sur Debian/Ubuntu.

================================================================================
TABLE DES MATIÈRES
================================================================================

1. Vue d'ensemble
2. Prérequis
3. Installation rapide
4. Structure des fichiers
5. Installation détaillée
6. Configuration SSL
7. Backups automatiques
8. Configuration des clients
9. Monitoring et maintenance
10. Dépannage
11. Sécurité

================================================================================
1. VUE D'ENSEMBLE
================================================================================

Baïkal est un serveur CalDAV/CardDAV léger qui vous permet d'héberger vos
propres calendriers et contacts. Cette installation inclut:

✓ Installation automatisée de Baïkal
✓ Configuration Nginx avec support HTTPS
✓ Support SQLite ou MySQL
✓ Backups automatiques
✓ Scripts de monitoring
✓ Documentation complète pour les clients

AVANTAGES:
- Contrôle total de vos données
- Synchronisation multi-appareils (iOS, Android, Desktop)
- Interface web d'administration
- Open source et gratuit
- Sécurisé avec HTTPS

================================================================================
2. PRÉREQUIS
================================================================================

SYSTÈME:
- Debian 10+ ou Ubuntu 20.04+
- Accès root (sudo)
- 512 Mo RAM minimum (1 Go recommandé)
- 1 Go d'espace disque minimum

RÉSEAU (pour accès distant):
- Nom de domaine pointant vers votre serveur
- Port 80 (HTTP) et 443 (HTTPS) ouverts
- Adresse IP publique

POUR ACCÈS LOCAL UNIQUEMENT:
- Aucun prérequis réseau particulier

================================================================================
3. INSTALLATION RAPIDE
================================================================================

# 1. Télécharger les scripts
git clone [votre-repo] ou télécharger les fichiers

# 2. Rendre les scripts exécutables
chmod +x *.sh

# 3. Lancer l'installation principale
sudo ./baikal_install.sh

# 4. Suivre l'assistant de configuration
# - Choisir le nom de domaine ou localhost
# - Choisir SQLite ou MySQL
# - Laisser l'installation se terminer

# 5. Configurer via l'interface web
# Ouvrir http://localhost/ ou http://votre-domaine.com/
# Suivre l'assistant de configuration initial

# 6. (Optionnel) Configurer HTTPS pour accès distant
sudo ./setup_ssl.sh

# 7. (Optionnel) Configurer les backups automatiques
sudo ./setup_backup.sh

================================================================================
4. STRUCTURE DES FICHIERS
================================================================================

baikal_install.sh       - Script principal d'installation
setup_ssl.sh            - Configuration HTTPS avec Let's Encrypt
setup_backup.sh         - Configuration des backups automatiques
backup_baikal.sh        - Script de backup manuel
monitor_baikal.sh       - Script de monitoring du système

GUIDE_CLIENTS.txt       - Guide de configuration des clients
MYSQL_CONFIG.txt        - Configuration avancée MySQL
README.txt              - Ce fichier

APRÈS INSTALLATION:
/var/www/baikal/                    - Installation de Baïkal
/etc/nginx/sites-available/baikal   - Configuration Nginx
/var/backups/baikal/                - Backups
/var/log/nginx/baikal_*.log         - Logs
/root/baikal_install_info.txt       - Informations d'installation

================================================================================
5. INSTALLATION DÉTAILLÉE
================================================================================

ÉTAPE 1: PRÉPARATION
--------------------
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Vérifier l'espace disque
df -h

ÉTAPE 2: INSTALLATION DE BAÏKAL
-------------------------------
sudo ./baikal_install.sh

Le script va:
1. Installer les dépendances (PHP, Nginx, MySQL si demandé)
2. Télécharger et installer Baïkal
3. Configurer Nginx
4. Configurer les permissions
5. Créer les fichiers de configuration

CHOIX DURANT L'INSTALLATION:
- Nom de domaine: 
  * Laisser vide pour accès local uniquement
  * Entrer votre domaine pour accès distant (ex: cal.example.com)

- Base de données:
  * SQLite: Simple, parfait pour usage personnel/petit groupe
  * MySQL: Meilleur pour gros volumes ou nombreux utilisateurs

ÉTAPE 3: CONFIGURATION INITIALE WEB
-----------------------------------
1. Ouvrir l'interface web (http://localhost/ ou http://votre-domaine.com/)
2. L'assistant de configuration s'affiche
3. Configurer l'administrateur:
   - Nom d'utilisateur admin
   - Mot de passe (fort!)
   - Email
4. Configurer la base de données (pré-rempli si MySQL)
5. Cliquer sur "Enregistrer"
6. Se connecter avec le compte admin
7. Créer des utilisateurs CalDAV/CardDAV

ÉTAPE 4: CRÉER DES UTILISATEURS
-------------------------------
Dans l'interface web:
1. Aller dans "Utilisateurs et droits"
2. Cliquer sur "Ajouter un utilisateur"
3. Entrer:
   - Nom d'utilisateur (identifiant de connexion)
   - Nom d'affichage
   - Email
   - Mot de passe
4. Les calendriers et carnets d'adresses sont créés automatiquement

================================================================================
6. CONFIGURATION SSL (POUR ACCÈS DISTANT)
================================================================================

IMPORTANT: SSL est REQUIS pour accès distant sécurisé!

PRÉREQUIS:
- Nom de domaine configuré
- DNS pointant vers votre serveur
- Ports 80 et 443 accessibles

INSTALLATION:
sudo ./setup_ssl.sh

Le script va:
1. Installer Certbot
2. Obtenir un certificat Let's Encrypt
3. Configurer Nginx pour HTTPS
4. Configurer le renouvellement automatique

APRÈS INSTALLATION SSL:
- Accès: https://votre-domaine.com/
- Certificat auto-renouvelé tous les 60 jours
- HTTP redirigé automatiquement vers HTTPS

VÉRIFICATION:
# Test de renouvellement
sudo certbot renew --dry-run

# Voir les certificats installés
sudo certbot certificates

================================================================================
7. BACKUPS AUTOMATIQUES
================================================================================

CONFIGURATION:
sudo ./setup_backup.sh

CHOIX DE FRÉQUENCE:
1. Quotidien (3h du matin)
2. Hebdomadaire (dimanche 3h)
3. Personnalisé (cron personnalisé)

CE QUI EST SAUVEGARDÉ:
- Toutes les données Baïkal (calendriers, contacts)
- Base de données (SQLite ou MySQL)
- Configuration Nginx
- Rétention: 30 jours par défaut

EMPLACEMENT:
/var/backups/baikal/

COMMANDES:
# Backup manuel
sudo /usr/local/bin/backup_baikal.sh

# Voir les backups
ls -lh /var/backups/baikal/

# Voir le log des backups
sudo tail -f /var/log/baikal_backup.log

RESTAURATION:
Voir le fichier /root/baikal_backup_config.txt pour les instructions
complètes de restauration.

BACKUP RAPIDE:
sudo tar -czf ~/baikal_manual_backup.tar.gz \
    /var/www/baikal/Specific \
    /var/www/baikal/config

================================================================================
8. CONFIGURATION DES CLIENTS
================================================================================

Voir le fichier GUIDE_CLIENTS.txt pour des instructions détaillées sur
la configuration de:

- iOS (iPhone/iPad)
- Android (DAVx⁵)
- macOS
- Windows (Outlook, eM Client)
- Linux (Evolution, GNOME Calendar)
- Thunderbird (Lightning, CardBook)

INFORMATIONS DE CONNEXION:
- Serveur: votre-domaine.com (ou localhost)
- Port: 443 (HTTPS) ou 80 (HTTP local)
- Utilisateur: [créé dans Baïkal]
- Mot de passe: [défini dans Baïkal]
- URL: https://votre-domaine.com/dav.php

CHEMINS DAV:
- Calendriers: /dav.php/calendars/[utilisateur]/[calendrier]/
- Contacts: /dav.php/addressbooks/[utilisateur]/[carnet]/

================================================================================
9. MONITORING ET MAINTENANCE
================================================================================

MONITORING:
sudo ./monitor_baikal.sh

Affiche:
- Status des services
- Espace disque
- Erreurs dans les logs
- Statistiques d'utilisation
- État du certificat SSL
- Derniers backups
- Permissions

LOGS:
# Logs Nginx
sudo tail -f /var/log/nginx/baikal_access.log
sudo tail -f /var/log/nginx/baikal_error.log

# Logs système
sudo journalctl -u nginx -f
sudo journalctl -u php*-fpm -f

# Logs Baïkal
sudo tail -f /var/www/baikal/Specific/logs/*

MAINTENANCE RÉGULIÈRE:
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Vérification des services
sudo systemctl status nginx
sudo systemctl status php*-fpm

# Test de la configuration Nginx
sudo nginx -t

# Optimisation base SQLite (si applicable)
sqlite3 /var/www/baikal/Specific/db/db.sqlite "VACUUM;"

# Optimisation MySQL (si applicable)
mysqlcheck -u baikal -p --optimize baikal

# Renouvellement SSL
sudo certbot renew

REDÉMARRAGE DES SERVICES:
sudo systemctl restart nginx
sudo systemctl restart php*-fpm

MISE À JOUR DE BAÏKAL:
1. Faire un backup complet
2. Télécharger la nouvelle version
3. Extraire dans /var/www/baikal
4. Conserver les dossiers Specific/ et config/
5. Mettre à jour les permissions
6. Tester

================================================================================
10. DÉPANNAGE
================================================================================

PROBLÈME: "Cannot connect to server"
SOLUTION:
1. Vérifier que Nginx est actif: systemctl status nginx
2. Vérifier le firewall: sudo ufw status
3. Vérifier les logs: /var/log/nginx/baikal_error.log
4. Tester localement: curl http://localhost/

PROBLÈME: "Authentication failed"
SOLUTION:
1. Vérifier les credentials dans l'interface web
2. Vérifier que l'utilisateur est activé
3. Réinitialiser le mot de passe dans l'interface admin
4. Vérifier les logs: grep auth /var/log/nginx/baikal_error.log

PROBLÈME: "503 Service Unavailable"
SOLUTION:
1. Vérifier PHP-FPM: systemctl status php*-fpm
2. Vérifier les permissions: ls -la /var/www/baikal/Specific
3. Redémarrer PHP-FPM: systemctl restart php*-fpm
4. Vérifier: /var/log/php*-fpm.log

PROBLÈME: "SSL certificate error"
SOLUTION:
1. Vérifier le certificat: sudo certbot certificates
2. Renouveler manuellement: sudo certbot renew
3. Vérifier la configuration Nginx: sudo nginx -t
4. Redémarrer Nginx: sudo systemctl restart nginx

PROBLÈME: "Database error"
SOLUTION:
SQLite:
- Vérifier les permissions: ls -la /var/www/baikal/Specific/db/
- Vérifier l'intégrité: sqlite3 db.sqlite "PRAGMA integrity_check;"
MySQL:
- Vérifier MySQL: systemctl status mysql
- Tester connexion: mysql -u baikal -p
- Vérifier config: /var/www/baikal/Specific/config.php

PROBLÈME: "Sync not working"
SOLUTION:
1. Forcer une synchronisation manuelle sur le client
2. Vérifier les logs du client
3. Vérifier les URLs CalDAV/CardDAV
4. Tester avec curl (voir GUIDE_CLIENTS.txt)
5. Vérifier les permissions dans Baïkal

PROBLÈME: Performances lentes
SOLUTION:
1. Vérifier l'espace disque: df -h
2. Optimiser la base de données (voir MYSQL_CONFIG.txt)
3. Augmenter les ressources PHP dans /etc/php/*/fpm/php.ini
4. Vérifier le nombre de connexions: netstat -an | grep :443 | wc -l
5. Analyser les logs pour requêtes lentes

COMMANDES DE DIAGNOSTIC:
# Test complet du système
sudo ./monitor_baikal.sh

# Test de connectivité
curl -I http://localhost/
curl -I https://votre-domaine.com/

# Vérifier les processus
ps aux | grep nginx
ps aux | grep php-fpm

# Vérifier les ports
sudo netstat -tulpn | grep -E ':(80|443)'

# Test CalDAV
curl -u utilisateur:password https://votre-domaine.com/dav.php/calendars/utilisateur/

================================================================================
11. SÉCURITÉ
================================================================================

BONNES PRATIQUES:

1. MOTS DE PASSE:
   - Utilisez des mots de passe forts (12+ caractères)
   - Changez-les régulièrement
   - Ne réutilisez pas les mêmes mots de passe

2. HTTPS OBLIGATOIRE:
   - N'exposez JAMAIS Baïkal sur Internet sans HTTPS
   - Vérifiez régulièrement le certificat SSL

3. FIREWALL:
   # Installer et configurer UFW
   sudo apt install ufw
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow ssh
   sudo ufw allow http
   sudo ufw allow https
   sudo ufw enable

4. MISES À JOUR:
   # Automatiser les mises à jour de sécurité
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure --priority=low unattended-upgrades

5. FAIL2BAN:
   # Protection contre brute-force
   sudo apt install fail2ban
   # Créer /etc/fail2ban/jail.local avec configuration Nginx

6. PERMISSIONS:
   # Ne jamais utiliser 777
   # Vérifier régulièrement:
   find /var/www/baikal -type d -perm 777

7. BACKUPS:
   # Toujours crypter les backups distants
   # Tester régulièrement la restauration

8. MONITORING:
   # Surveiller les tentatives de connexion
   grep "401\|403" /var/log/nginx/baikal_access.log

9. ACCÈS ADMIN:
   # Limiter l'accès à l'interface admin par IP si possible
   # Dans la config Nginx, ajouter:
   location /admin {
       allow 192.168.1.0/24;
       deny all;
   }

10. AUDIT:
    # Logs à surveiller régulièrement
    - /var/log/nginx/baikal_error.log
    - /var/log/auth.log
    - journalctl -u nginx

================================================================================
12. COMMANDES UTILES RÉCAPITULATIVES
================================================================================

# Installation
sudo ./baikal_install.sh              # Installation complète
sudo ./setup_ssl.sh                   # Configuration SSL
sudo ./setup_backup.sh                # Configuration backups

# Monitoring
sudo ./monitor_baikal.sh              # Status complet
sudo systemctl status nginx           # Status Nginx
sudo systemctl status php*-fpm        # Status PHP

# Logs
sudo tail -f /var/log/nginx/baikal_error.log
sudo journalctl -u nginx -f

# Maintenance
sudo systemctl restart nginx          # Redémarrer Nginx
sudo systemctl restart php*-fpm       # Redémarrer PHP-FPM
sudo nginx -t                         # Tester config Nginx
sudo certbot renew                    # Renouveler SSL

# Backups
sudo /usr/local/bin/backup_baikal.sh  # Backup manuel
ls -lh /var/backups/baikal/          # Voir backups

# Base de données
sqlite3 /var/www/baikal/Specific/db/db.sqlite  # SQLite
mysql -u baikal -p baikal                       # MySQL

================================================================================
13. SUPPORT ET RESSOURCES
================================================================================

DOCUMENTATION:
- Baïkal: https://sabre.io/baikal/
- sabre/dav: https://sabre.io/dav/
- Nginx: https://nginx.org/en/docs/
- Let's Encrypt: https://letsencrypt.org/docs/

COMMUNAUTÉ:
- GitHub Baïkal: https://github.com/sabre-io/Baikal
- Issues: https://github.com/sabre-io/Baikal/issues
- Discussions: https://github.com/sabre-io/Baikal/discussions

FICHIERS D'INFO LOCAUX:
- /root/baikal_install_info.txt
- /root/baikal_ssl_info.txt
- /root/baikal_backup_config.txt

AIDE:
Pour toute question ou problème:
1. Vérifier ce README
2. Consulter GUIDE_CLIENTS.txt pour clients
3. Consulter MYSQL_CONFIG.txt pour MySQL
4. Exécuter monitor_baikal.sh pour diagnostics
5. Consulter les logs
6. Ouvrir une issue sur GitHub

================================================================================

Bon calendrier! 📅 🎉

Installation créée par: Claude (Anthropic)
Version: 1.0
Dernière mise à jour: 2025
