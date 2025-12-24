# Guide de sécurité Baïkal

## Checklist de sécurité

Utilisez cette checklist après installation:

- [ ] HTTPS configuré (Let's Encrypt)
- [ ] Firewall actif (UFW)
- [ ] Mots de passe forts
- [ ] Backups automatiques
- [ ] Mises à jour système activées
- [ ] Fail2ban installé
- [ ] Monitoring actif
- [ ] Logs surveillés

## HTTPS obligatoire

### Configuration SSL

```bash
sudo ./install/setup_ssl.sh
```

### Forcer HTTPS

Dans `/etc/nginx/sites-available/baikal`:

```nginx
server {
    listen 80;
    server_name votre-domaine.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name votre-domaine.com;
    
    # Certificats SSL
    ssl_certificate /etc/letsencrypt/live/votre-domaine.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/votre-domaine.com/privkey.pem;
    
    # SSL moderne
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Headers sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # ...
}
```

### Vérifier configuration SSL

```bash
# Test local
sudo nginx -t

# Test en ligne
# https://www.ssllabs.com/ssltest/
```

## Firewall (UFW)

### Installation

```bash
sudo apt install -y ufw
```

### Configuration

```bash
# Par défaut: bloquer tout
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Autoriser SSH
sudo ufw allow 22/tcp

# Autoriser HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Activer firewall
sudo ufw enable

# Vérifier
sudo ufw status verbose
```

### Limiter tentatives SSH

```bash
sudo ufw limit 22/tcp
```

## Mots de passe forts

### Pour Baïkal

Minimum requis:
- 12+ caractères
- Majuscules + minuscules
- Chiffres
- Symboles

Exemple: `Bk@2025!SecureP@ss#`

### Générateur

```bash
# Générer mot de passe aléatoire
openssl rand -base64 24
```

### Politique de mots de passe

Dans l'interface Baïkal:
1. Comptes admin séparés des utilisateurs
2. Changer mots de passe régulièrement
3. Pas de réutilisation

## Fail2ban

### Installation

```bash
sudo apt install -y fail2ban
```

### Configuration Nginx

Créer `/etc/fail2ban/filter.d/nginx-baikal.conf`:

```ini
[Definition]
failregex = ^<HOST> .* ".*" (401|403) .*$
ignoreregex =
```

Créer `/etc/fail2ban/jail.d/nginx-baikal.conf`:

```ini
[nginx-baikal]
enabled = true
port = http,https
filter = nginx-baikal
logpath = /var/log/nginx/baikal_access.log
maxretry = 5
findtime = 600
bantime = 3600
```

### Activer

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# Vérifier
sudo fail2ban-client status nginx-baikal
```

## Permissions fichiers

### Permissions correctes

```bash
sudo chown -R www-data:www-data /var/www/baikal
sudo chmod -R 755 /var/www/baikal
sudo chmod -R 770 /var/www/baikal/Specific
sudo chmod -R 770 /var/www/baikal/config
sudo chmod 660 /var/www/baikal/Specific/db/db.sqlite
```

### Vérifier régulièrement

```bash
sudo ./troubleshoot/fix_permissions.sh
```

## Mises à jour

### Mises à jour système

```bash
# Configuration auto-updates
sudo apt install -y unattended-upgrades

# Activer
sudo dpkg-reconfigure -plow unattended-upgrades

# Vérifier config
cat /etc/apt/apt.conf.d/50unattended-upgrades
```

### Mises à jour Baïkal

```bash
# Vérifier
sudo ./maintenance/check_updates.sh

# Mettre à jour
sudo ./maintenance/update.sh
```

### Mises à jour PHP

```bash
# Vérifier version
php -v

# Mettre à jour si besoin
sudo ./install/upgrade_php.sh
```

## Backups sécurisés

### Configuration backups

```bash
sudo ./maintenance/setup_backup.sh
```

### Backups chiffrés

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP="/var/backups/baikal/baikal_$DATE.tar.gz"

# Backup normal
tar -czf "$BACKUP" -C /var/www/baikal Specific config

# Chiffrement
gpg --symmetric --cipher-algo AES256 "$BACKUP"
rm "$BACKUP"

echo "Backup chiffré: ${BACKUP}.gpg"
```

### Backups distants

```bash
# Copier vers serveur distant
rsync -avz --delete /var/backups/baikal/ user@backup-server:/backups/baikal/

# Ou Amazon S3
aws s3 sync /var/backups/baikal/ s3://mon-bucket/baikal/
```

## Monitoring et logs

### Monitoring actif

```bash
# Monitoring quotidien
sudo ./maintenance/monitor.sh

# Ajouter à cron
(crontab -l; echo "0 8 * * * /chemin/vers/maintenance/monitor.sh | mail -s 'Rapport Baïkal' admin@example.com") | crontab -
```

### Rotation logs

Créer `/etc/logrotate.d/baikal`:

```
/var/log/nginx/baikal_*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### Analyser logs

```bash
# Rechercher erreurs
sudo grep -i error /var/log/nginx/baikal_error.log | tail -20

# Rechercher tentatives de connexion
sudo grep "401\|403" /var/log/nginx/baikal_access.log

# IPs les plus actives
sudo awk '{print $1}' /var/log/nginx/baikal_access.log | sort | uniq -c | sort -rn | head -20
```

## Isolation réseau

### Accès local uniquement

Si Baïkal est uniquement local:

```nginx
server {
    listen 127.0.0.1:80;
    # ...
}
```

### VPN

Pour accès distant sécurisé sans exposer le serveur:

1. Installer WireGuard/OpenVPN
2. Configurer Nginx sur localhost uniquement
3. Accéder via VPN

## Base de données

### SQLite

```bash
# Permissions strictes
sudo chmod 660 /var/www/baikal/Specific/db/db.sqlite
sudo chown www-data:www-data /var/www/baikal/Specific/db/db.sqlite
```

### MySQL

```bash
# Utilisateur avec privilèges minimaux
sudo mysql << SQL
CREATE USER 'baikal'@'localhost' IDENTIFIED BY 'MOT_DE_PASSE_FORT';
GRANT SELECT, INSERT, UPDATE, DELETE ON baikal.* TO 'baikal'@'localhost';
FLUSH PRIVILEGES;
SQL

# Bind localhost uniquement
# Dans /etc/mysql/mysql.conf.d/mysqld.cnf:
bind-address = 127.0.0.1
```

## Headers de sécurité

Dans `/etc/nginx/sites-available/baikal`:

```nginx
# HSTS - Force HTTPS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Empêche clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# Protection XSS
add_header X-XSS-Protection "1; mode=block" always;

# Empêche MIME sniffing
add_header X-Content-Type-Options "nosniff" always;

# Referrer policy
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# CSP (Content Security Policy)
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;

# Permissions Policy
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

## Audit de sécurité

### Scanner ports

```bash
# Depuis machine externe
nmap -sV votre-domaine.com

# Devrait montrer uniquement 80, 443 (et 22 si SSH)
```

### Test SSL

```bash
# Test SSLLabs
# https://www.ssllabs.com/ssltest/analyze.html?d=votre-domaine.com

# Test local
sudo testssl.sh https://votre-domaine.com
```

### Vérifier permissions

```bash
# Fichiers accessibles en écriture par tout le monde
find /var/www/baikal -type f -perm -002

# Devrait être vide
```

## Sécurité SSH

### Si accès SSH au serveur

```bash
# Désactiver root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Authentification par clé uniquement
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Changer port (optionnel)
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# Redémarrer SSH
sudo systemctl restart sshd
```

## Conformité RGPD

### Données personnelles

Baïkal stocke:
- Noms d'utilisateurs
- Emails
- Calendriers (potentiellement sensibles)
- Contacts

### Bonnes pratiques

1. Informer utilisateurs du stockage
2. Permettre export données (iCal, vCard)
3. Permettre suppression compte
4. Backups chiffrés
5. Conservation limitée des logs

### Export données utilisateur

```bash
# Calendriers
sudo sqlite3 /var/www/baikal/Specific/db/db.sqlite \
  "SELECT * FROM calendarobjects WHERE calendarid IN (SELECT id FROM calendars WHERE principaluri LIKE '%username%');"

# Contacts
sudo sqlite3 /var/www/baikal/Specific/db/db.sqlite \
  "SELECT * FROM cards WHERE addressbookid IN (SELECT id FROM addressbooks WHERE principaluri LIKE '%username%');"
```

## Incident response

### En cas de compromission

1. Déconnecter serveur:
   ```bash
   sudo ufw deny 80/tcp
   sudo ufw deny 443/tcp
   ```

2. Sauvegarder état:
   ```bash
   sudo ./maintenance/backup.sh
   ```

3. Analyser logs:
   ```bash
   sudo grep -r "suspicious_ip" /var/log/
   ```

4. Changer tous mots de passe

5. Restaurer depuis backup propre

6. Renforcer sécurité avant remise en ligne

## Ressources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Mozilla SSL Config](https://ssl-config.mozilla.org/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)

## Contact sécurité

Pour signaler vulnérabilité:
- GitHub Security Advisory
- Email: security@sabre.io
