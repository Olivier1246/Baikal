# Guide de dépannage Baïkal

## Diagnostic rapide

```bash
# Diagnostic complet
sudo ./troubleshoot/diagnose.sh

# Monitoring état système
sudo ./maintenance/monitor.sh

# Vérifier logs
sudo tail -f /var/log/nginx/baikal_error.log
```

## Problèmes courants

### 1. Erreur 502 Bad Gateway

**Symptômes**: Page blanche avec erreur 502

**Causes**:
- PHP-FPM non démarré
- Configuration Nginx incorrecte
- Socket PHP incorrect

**Solutions**:

```bash
# Vérifier statut PHP-FPM
sudo systemctl status php*-fpm

# Redémarrer PHP-FPM
sudo systemctl restart php*-fpm

# Vérifier socket dans Nginx
grep fastcgi_pass /etc/nginx/sites-available/baikal

# Redémarrer Nginx
sudo systemctl restart nginx
```

### 2. Erreur 404 Not Found

**Symptômes**: Page non trouvée

**Causes**:
- Configuration Nginx incorrecte
- Fichiers Baïkal absents
- Permissions incorrectes

**Solutions**:

```bash
# Vérifier installation
ls -la /var/www/baikal/

# Vérifier config Nginx
nginx -t

# Vérifier permissions
sudo ./troubleshoot/fix_permissions.sh
```

### 3. "Permission denied"

**Symptômes**: Erreurs dans les logs, impossible de créer/modifier événements

**Causes**:
- Propriétaire incorrect
- Permissions trop restrictives

**Solution**:

```bash
sudo ./troubleshoot/fix_permissions.sh
```

### 4. "Database error" / Base corrompue

**Symptômes**: Erreur lors de l'accès, données manquantes

**Solutions**:

```bash
# Diagnostic base
sudo ./troubleshoot/diagnose.sh

# Réparation base
sudo ./troubleshoot/fix_database.sh
```

### 5. "Aucun agenda à cette adresse" (Thunderbird)

**Symptômes**: Thunderbird ne trouve pas les calendriers

**Causes**:
- URI principal incorrect (ex: `principals/Olivier` au lieu de `principals/users/olivier/`)

**Solution**:

```bash
# Corriger URIs
sudo ./troubleshoot/fix_principals.sh
```

Ensuite, utilisez les nouvelles URLs fournies.

### 6. Certificat SSL expiré

**Symptômes**: Avertissement navigateur, clients ne se connectent pas

**Solution**:

```bash
# Vérifier expiration
sudo certbot certificates

# Renouveler manuellement
sudo certbot renew

# Tester renouvellement auto
sudo certbot renew --dry-run
```

### 7. "Could not LOCK table" (MySQL)

**Symptômes**: Erreurs de verrouillage base MySQL

**Solution**:

```bash
# Redémarrer MySQL
sudo systemctl restart mysql

# Vérifier tables
sudo mysql baikal -e "CHECK TABLE addressbooks, calendars;"

# Réparer si nécessaire
sudo mysql baikal -e "REPAIR TABLE addressbooks, calendars;"
```

## Codes d'erreur HTTP

| Code | Signification | Solution |
|------|---------------|----------|
| 200 | OK | Tout fonctionne |
| 401 | Non autorisé | Vérifier identifiants |
| 403 | Interdit | Vérifier permissions |
| 404 | Non trouvé | Vérifier URL/config |
| 500 | Erreur serveur | Consulter logs |
| 502 | Bad Gateway | Redémarrer PHP-FPM |
| 503 | Service indisponible | Redémarrer services |

## Commandes de diagnostic

### Vérifier services

```bash
# Statut Nginx
sudo systemctl status nginx

# Statut PHP-FPM
sudo systemctl status php*-fpm

# Statut MySQL (si utilisé)
sudo systemctl status mysql

# Logs système
sudo journalctl -xe
```

### Vérifier fichiers

```bash
# Structure installation
tree -L 2 /var/www/baikal/

# Permissions
ls -la /var/www/baikal/Specific/
ls -la /var/www/baikal/config/

# Espace disque
df -h

# Taille base
du -sh /var/www/baikal/Specific/db/
```

### Tester connectivité

```bash
# Test HTTP local
curl -I http://localhost/

# Test HTTPS
curl -I https://votre-domaine.com/

# Test CalDAV
curl -u username:password https://votre-domaine.com/dav.php/
```

### Consulter logs

```bash
# Logs Nginx accès
sudo tail -100 /var/log/nginx/baikal_access.log

# Logs Nginx erreurs
sudo tail -100 /var/log/nginx/baikal_error.log

# Logs PHP
sudo tail -100 /var/log/php*-fpm.log

# Logs en temps réel
sudo tail -f /var/log/nginx/baikal_error.log
```

## Base de données

### SQLite

```bash
# Ouvrir base
sudo sqlite3 /var/www/baikal/Specific/db/db.sqlite

# Vérifier intégrité
PRAGMA integrity_check;

# Lister tables
.tables

# Voir utilisateurs
SELECT * FROM principals;

# Voir calendriers
SELECT * FROM calendars;

# Sortir
.quit
```

### MySQL

```bash
# Connexion
sudo mysql -u baikal -p baikal

# Lister tables
SHOW TABLES;

# Voir utilisateurs
SELECT * FROM principals;

# Vérifier tables
CHECK TABLE addressbooks, calendars;

# Quitter
exit
```

## Restauration

### Restaurer depuis backup

```bash
# Lister backups
ls -lh /var/backups/baikal/

# Arrêter services
sudo systemctl stop nginx php*-fpm

# Restaurer données
sudo tar -xzf /var/backups/baikal/baikal_YYYYMMDD_HHMMSS.tar.gz -C /var/www/baikal/

# Restaurer base SQLite
sudo cp /var/backups/baikal/baikal_db_YYYYMMDD_HHMMSS.sqlite /var/www/baikal/Specific/db/db.sqlite

# Permissions
sudo chown -R www-data:www-data /var/www/baikal/
sudo chmod 660 /var/www/baikal/Specific/db/db.sqlite

# Redémarrer
sudo systemctl start php*-fpm nginx
```

## Réinstallation propre

Si tout échoue:

```bash
# Backup données
sudo ./maintenance/backup.sh

# Désinstaller
sudo systemctl stop nginx php*-fpm
sudo rm -rf /var/www/baikal
sudo rm /etc/nginx/sites-available/baikal
sudo rm /etc/nginx/sites-enabled/baikal

# Réinstaller
sudo ./install/baikal_install.sh

# Restaurer données
sudo tar -xzf /var/backups/baikal/baikal_YYYYMMDD_HHMMSS.tar.gz -C /var/www/baikal/

# Permissions
sudo ./troubleshoot/fix_permissions.sh
```

## Problèmes clients

### iOS ne synchronise pas

1. Supprimer le compte
2. Redémarrer l'appareil
3. Recréer le compte
4. Vérifier connexion WiFi/4G

### Android (DAVx⁵) erreurs

1. Ouvrir DAVx⁵
2. Compte > Paramètres
3. Vérifier URL et identifiants
4. Forcer synchronisation
5. Consulter logs DAVx⁵

### Thunderbird: "MODIFICATION_FAILED"

Souvent causé par:
- Permissions incorrectes → `sudo ./troubleshoot/fix_permissions.sh`
- URIs non-standard → `sudo ./troubleshoot/fix_principals.sh`

## Logs utiles

### Activer debug Nginx

Éditez `/etc/nginx/sites-available/baikal`:

```nginx
error_log /var/log/nginx/baikal_error.log debug;
```

Puis:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Activer debug PHP

Éditez `/etc/php/*/fpm/php.ini`:

```ini
log_errors = On
error_log = /var/log/php_errors.log
error_reporting = E_ALL
display_errors = Off
```

Puis:
```bash
sudo systemctl restart php*-fpm
```

## Obtenir de l'aide

1. Lancez d'abord le diagnostic:
   ```bash
   sudo ./troubleshoot/diagnose.sh > diagnostic.txt
   ```

2. Consultez:
   - [Documentation Baïkal](https://sabre.io/baikal/)
   - [GitHub Issues](https://github.com/sabre-io/Baikal/issues)
   - [Forum sabre/dav](https://github.com/sabre-io/dav/discussions)

3. Fournissez:
   - Résultat du diagnostic
   - Logs pertinents
   - Version Baïkal
   - OS et version
