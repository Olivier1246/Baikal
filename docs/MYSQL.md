# Configuration MySQL pour Baïkal

## Quand utiliser MySQL ?

**SQLite** (par défaut):
- ✓ 1-10 utilisateurs
- ✓ Configuration simple
- ✓ Pas de serveur DB séparé
- ✓ Backups faciles

**MySQL** (recommandé si):
- ✓ 20+ utilisateurs
- ✓ Usage intensif
- ✓ Plusieurs serveurs
- ✓ Haute disponibilité

## Installation MySQL

### Lors de l'installation Baïkal

```bash
sudo ./install/baikal_install.sh
```

Choisissez "mysql" quand demandé, puis fournissez:
- Nom de base: `baikal`
- Utilisateur: `baikal`
- Mot de passe: (choisissez un mot de passe fort)

### Installation manuelle

```bash
# Installer MySQL
sudo apt update
sudo apt install -y mysql-server

# Sécuriser MySQL
sudo mysql_secure_installation
```

## Configuration MySQL

### Créer base et utilisateur

```bash
sudo mysql << SQL
CREATE DATABASE baikal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'baikal'@'localhost' IDENTIFIED BY 'VOTRE_MOT_DE_PASSE';
GRANT ALL PRIVILEGES ON baikal.* TO 'baikal'@'localhost';
FLUSH PRIVILEGES;
SQL
```

### Optimisation MySQL

Éditez `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
[mysqld]
# Encodage UTF-8
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Performance
max_connections = 100
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2

# Optimisation requêtes
query_cache_size = 16M
query_cache_type = 1
```

Redémarrer:
```bash
sudo systemctl restart mysql
```

## Configuration Baïkal pour MySQL

### Interface web

1. Première installation:
   - Type: MySQL
   - Hôte: `localhost`
   - Base: `baikal`
   - Utilisateur: `baikal`
   - Mot de passe: votre mot de passe

2. Test connexion avant de sauvegarder

### Fichier config manuel

Éditez `/var/www/baikal/Specific/config.system.php`:

```php
<?php
define("PROJECT_SQLITE_FILE", "");
define("PROJECT_DB_MYSQL", TRUE);
define("PROJECT_DB_MYSQL_HOST", "localhost");
define("PROJECT_DB_MYSQL_DBNAME", "baikal");
define("PROJECT_DB_MYSQL_USERNAME", "baikal");
define("PROJECT_DB_MYSQL_PASSWORD", "VOTRE_MOT_DE_PASSE");
```

## Migration SQLite → MySQL

### Méthode 1: Export/Import manuel

```bash
# Export SQLite
sqlite3 /var/www/baikal/Specific/db/db.sqlite .dump > baikal_export.sql

# Nettoyer pour MySQL
sed -i 's/BEGIN TRANSACTION/START TRANSACTION/g' baikal_export.sql
sed -i 's/AUTOINCREMENT/AUTO_INCREMENT/g' baikal_export.sql

# Importer dans MySQL
mysql -u baikal -p baikal < baikal_export.sql
```

### Méthode 2: Via Baïkal

1. Installer Baïkal avec MySQL vide
2. Créer utilisateurs via interface
3. Recopier données manuellement

## Backups MySQL

### Backup complet

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/baikal"

mkdir -p "$BACKUP_DIR"

mysqldump -u baikal -p baikal | gzip > "$BACKUP_DIR/baikal_mysql_$DATE.sql.gz"

# Rétention 30 jours
find "$BACKUP_DIR" -name "baikal_mysql_*.sql.gz" -mtime +30 -delete
```

### Backup automatique

Ajouter à cron:

```bash
# Éditer crontab
sudo crontab -e

# Ajouter (backup quotidien à 3h)
0 3 * * * /usr/local/bin/backup_baikal_mysql.sh >> /var/log/baikal_mysql_backup.log 2>&1
```

### Restauration

```bash
# Décompresser
gunzip baikal_mysql_YYYYMMDD_HHMMSS.sql.gz

# Restaurer
mysql -u baikal -p baikal < baikal_mysql_YYYYMMDD_HHMMSS.sql
```

## Maintenance MySQL

### Vérifier tables

```bash
sudo mysql -u baikal -p baikal << SQL
CHECK TABLE addressbooks;
CHECK TABLE calendars;
CHECK TABLE principals;
SQL
```

### Optimiser tables

```bash
sudo mysql -u baikal -p baikal << SQL
OPTIMIZE TABLE addressbooks;
OPTIMIZE TABLE calendars;
OPTIMIZE TABLE principals;
SQL
```

### Analyser tables

```bash
sudo mysql -u baikal -p baikal << SQL
ANALYZE TABLE addressbooks;
ANALYZE TABLE calendars;
ANALYZE TABLE principals;
SQL
```

## Monitoring MySQL

### Statistiques

```bash
sudo mysql -u baikal -p baikal << SQL
SELECT TABLE_NAME, TABLE_ROWS, 
       ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'baikal';
SQL
```

### Connexions actives

```bash
sudo mysql -e "SHOW PROCESSLIST;"
```

### Variables importantes

```bash
sudo mysql -e "SHOW VARIABLES LIKE 'max_connections';"
sudo mysql -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
```

## Problèmes courants

### "Access denied"

```bash
# Vérifier utilisateur
sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User='baikal';"

# Recréer utilisateur
sudo mysql << SQL
DROP USER 'baikal'@'localhost';
CREATE USER 'baikal'@'localhost' IDENTIFIED BY 'NOUVEAU_MOT_DE_PASSE';
GRANT ALL PRIVILEGES ON baikal.* TO 'baikal'@'localhost';
FLUSH PRIVILEGES;
SQL
```

### "Can't connect to MySQL server"

```bash
# Vérifier MySQL actif
sudo systemctl status mysql

# Redémarrer
sudo systemctl restart mysql

# Vérifier port
sudo ss -tuln | grep 3306
```

### "Table is marked as crashed"

```bash
sudo mysql -u baikal -p baikal << SQL
REPAIR TABLE calendars;
REPAIR TABLE addressbooks;
SQL
```

## Performance

### Activer slow query log

Éditez `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
```

### Analyser queries lentes

```bash
sudo mysqldumpslow /var/log/mysql/mysql-slow.log
```

## Sécurité MySQL

### Utilisateur dédié

```bash
# Créer utilisateur lecture seule pour monitoring
sudo mysql << SQL
CREATE USER 'baikal_ro'@'localhost' IDENTIFIED BY 'PASSWORD';
GRANT SELECT ON baikal.* TO 'baikal_ro'@'localhost';
FLUSH PRIVILEGES;
SQL
```

### Bind sur localhost uniquement

Éditez `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
bind-address = 127.0.0.1
```

### Mots de passe forts

```bash
sudo mysql << SQL
ALTER USER 'baikal'@'localhost' IDENTIFIED BY 'MOT_DE_PASSE_TRES_FORT_32_CHARS';
FLUSH PRIVILEGES;
SQL
```
