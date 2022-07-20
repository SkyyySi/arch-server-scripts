#!/usr/bin/env bash
__OLD_DIR="${__OLD_DIR:-$PWD}"
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&>/dev/null&&pwd)" || exit 2

source '../../include/elevate.sh'
source '../../include/install-deps.sh'


# This script require root privileges
if [[ "${EUID}" != 0 ]]; then
	exec "${0}" "${@}"
fi


# Install dependencies
install-deps mysql caddy php-fpm php-igbinary php-redis redis nextcloud php-imagick php-intl \
	nextcloud-app-{bookmarks,calendar,contacts,deck,mail,news,notes,notify_push,spreed,tasks}

mkdir -p '/etc/systemd/system/nextcloud-cron.service.d'
cp './nextcloud-cron_override.conf' '/etc/systemd/system/nextcloud-cron.service.d/override.conf'


# Memory cache (redis)
usermod -G redis,http caddy
usermod -G redis nextcloud

cp '/etc/redis/redis.conf' '/etc/redis/redis.conf_orig'
sed 's|^# unixsocket /run/redis.sock$|unixsocket /run/redis/redis.sock|' -i '/etc/redis/redis.conf'
sed 's|^# unixsocketperm 700$|unixsocketperm 770|' -i '/etc/redis/redis.conf'
sed 's|^# port 0$|port 0|' -i '/etc/redis/redis.conf'

systemctl enable --now redis.service nextcloud-cron.timer


# Database (MySQL)

## Create a MySQL database if it doesn't already exit
if [[ -z "$(ls '/var/lib/mysql')" ]]; then
	mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

## Restrict access to listen only on a local Unix socket (for security)
cp '/etc/my.cnf.d/server.cnf' '/etc/my.cnf.d/server.cnf_old'
if ! grep -woq '^skip_networking' '/etc/my.cnf.d/server.cnf'; then
	sed '/^\[mysqld\]/a skip_networking' -i '/etc/my.cnf.d/server.cnf'
fi

if ! grep -woq '^transaction_isolation=.*' '/etc/my.cnf.d/server.cnf'; then
	sed '/^\[mysqld\]/a transaction_isolation=READ-COMMITTED' -i '/etc/my.cnf.d/server.cnf'
fi

## Enable and start the systemd unit
systemctl enable --now mysql.service

## Ask the user to set a new password if one isn't already defined
if mysql -u root -e 'quit' &> /dev/null; then
	mysql_password="$(systemd-ask-password 'Enter a new password for the MySQL root user (leave empty for no password):')"
	mysql_password_verify="$(systemd-ask-password 'Please repeat it (for verification):')"

	if [[ "${mysql_password}" != "${mysql_password_verify}" ]]; then
		echo "Your passwords don't appear to match. Exiting."
		exit 1
	fi

	mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_password}'; flush privileges;"
fi

## Create the "nextcloud" database user and database
nextcloud_password="$(systemd-ask-password 'Enter a new password for the "nextcloud" database (leave empty for no password):')"
nextcloud_password_verify="$(systemd-ask-password 'Please repeat it (for verification):')"

if [[ "${nextcloud_password}" != "${nextcloud_password_verify}" ]]; then
	echo "Your passwords don't appear to match. Exiting."
	exit 1
fi

mysql -u root --password="${mysql_password}" -e "CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '${nextcloud_password}';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES on nextcloud.* to 'nextcloud'@'localhost';
FLUSH privileges;"


# php

## Create a copy to not break any other PHP apps
cp '/etc/php/php.ini' '/etc/webapps/nextcloud'

# Determine the timezone
timezone=""
new_timezone=""

if [[ -e '/etc/timezone' ]]; then
	timezone="$(cat '/etc/timezone')"
else
	timezone="$(timedatectl status | grep -woP 'Time zone: \K.*/[^ ]*')"
fi

echo
echo ">>> Your timezone appears to be '${timezone}'. If this is correct, just hit enter/return."
echo ">>> If it is not (or you wish to use a different timezone for Nextcloud), please type your"
echo ">>> desired timezone and then hit enter/return."
read -r -p '> ' new_timezone

if [[ "${new_timezone}" != "" ]]; then
	timezone="${new_timezone}"
	echo ">>> Timezone: ${timezone}"
fi

## Modify it with some required extensions
php_config_addtions="
; below are settings added by arch-server-scripts
extension=bcmath
extension=bz2
extension=exif
extension=gd
extension=iconv
; in case you installed php-imagick (as recommended)
extension=imagick
; in case you also installed php-intl (as recommended)
extension=intl
; use mysql as the database
extension=pdo_mysql

; enable in-memory caching (using redis)
extension=igbinary
extension=redis

redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000

date.timezone = ${timezone}

; Security hardening - restrincts possible read/write locations
open_basedir=/var/lib/nextcloud/data:/var/lib/nextcloud/apps:/tmp:/usr/share/webapps/nextcloud:/etc/webapps/nextcloud:/dev/urandom:/usr/lib/php/modules:/var/log/nextcloud:/proc/meminfo:/run/redis
"
echo "${php_config_addtions}" >> '/etc/webapps/nextcloud/php.ini'
sed 's/memory_limit = .*/memory_limit = 4096M/' -i '/etc/webapps/nextcloud/php.ini'
chown nextcloud:nextcloud '/etc/webapps/nextcloud/php.ini'

## Configure Nextcloud
echo
echo ">>> You will now have to provide the domains Nextcloud should trust. Note that"
echo ">>> 127.0.0.1, localhost and localho.st are always on this list."
echo ">>> When you are done, leave the prompt empty and just hit enter/return."

trusted_domains=('127.0.0.1' 'localhost' 'localho.st')
additional_domain="-"

while [[ "${additional_domain}" != "" ]]; do
	read -r -p '> ' additional_domain

	if [[ "${additional_domain}" != "" ]]; then
		trusted_domains+=("${additional_domain}")
	fi
done

nextcloud_config="
<?php
\$CONFIG = [
  'datadirectory' => '/var/lib/nextcloud/data',
  'logfile' => '/var/log/nextcloud/nextcloud.log',
  'apps_paths' => [
    [
      'path'=> '/usr/share/webapps/nextcloud/apps',
      'url' => '/apps',
      'writable' => false,
    ],
    [
      'path'=> '/var/lib/nextcloud/apps',
      'url' => '/wapps',
      'writable' => true,
    ],
  ],
  'trusted_domains' => [
"

for i in "${!trusted_domains[@]}"; do
	nextcloud_config=$"${nextcloud_config}    ${i} => '${trusted_domains[i]}',
"
done

nextcloud_config="${nextcloud_config}  ],
  'overwrite.cli.url' => 'https://cloud.example.org/',
  'htaccess.RewriteBase' => '/',
];
"

mv '/etc/webapps/nextcloud/config/config.php' '/etc/webapps/nextcloud/config/config.php_orig'
echo "${nextcloud_config}" >> '/etc/webapps/nextcloud/config/config.php'
chown nextcloud:nextcloud '/etc/webapps/nextcloud/config/config.php'

## Environment setup
export NEXTCLOUD_PHP_CONFIG='/etc/webapps/nextcloud/php.ini'
echo "export NEXTCLOUD_PHP_CONFIG='/etc/webapps/nextcloud/php.ini'" >> '/etc/profile.d/nextcloud_env.sh'
install --owner=nextcloud --group=nextcloud --mode=700 -d '/var/lib/nextcloud/sessions'

## Create an admin account for Nextcloud
nextcloud_admin_email=""
echo
while [[ "${nextcloud_admin_email}" = "" ]]; do
	read -r -p 'Enter a new e-mail address for the Nextcloud admin account: ' nextcloud_admin_email
done

nextcloud_admin_password=""
while [[ "${nextcloud_admin_password}" = "" ]]; do
	nextcloud_admin_password="$(systemd-ask-password 'Enter a new password for the Nextcloud admin account:')"
done
nextcloud_admin_password_verify="$(systemd-ask-password 'Please repeat it (for verification):')"

if [[ "${nextcloud_admin_password}" != "${nextcloud_admin_password_verify}" ]]; then
	echo "Your passwords don't appear to match. Exiting."
	exit 1
fi

occ maintenance:install \
	--database="mysql" \
	--database-name="nextcloud" \
	--database-host="localhost:/run/mysqld/mysqld.sock" \
	--database-user="nextcloud" \
	--database-pass="${nextcloud_password}" \
	--admin-pass="${nextcloud_admin_password}" \
	--admin-email="${nextcloud_admin_email}" \
	--data-dir="/var/lib/nextcloud/data"

# Make sure to manually run
#occ notify_push:setup https://your.nextcloud.com/push

for i in "${!trusted_domains[@]}"; do
	occ config:system:set trusted_domains "${i}" --value="${trusted_domains[i]}"
done

# Enable caching via redis
sed "/^);/i   'memcache.local' => 'OCMemcacheRedis',\n  'memcache.distributed' => 'OCMemcacheRedis',\n  'memcache.locking' => 'OCMemcacheRedis',\n  'redis' => [\n    'host'     => '/run/redis/redis.sock',\n    'port'     => 0,\n    'dbindex'  => 0,\n    'timeout'  => 1.5,\n  ]," -i '/etc/webapps/nextcloud/config/config.php'
sed 's|OCMemcacheRedis|\\OC\\Memcache\\Redis|g' -i '/etc/webapps/nextcloud/config/config.php'

occ config:system:set memcache.local --value="\OC\Memcache\Redis"
occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
occ config:system:set memcache.locking --value="\OC\Memcache\Redis"
occ config:system:set redis host --value="/run/redis/redis.sock"
occ config:system:set redis port --value="0" --type="integer"
occ config:system:set redis dbindex --value="0" --type="integer"
occ config:system:set redis timeout --value="1.5" --type="double"
# TODO: Find out why the above completely breaks nextcloud

# Enable the installed Nextcloud apps
occ app:enable bookmarks
occ app:enable calendar
occ app:enable contacts
occ app:enable deck
occ app:enable mail
occ app:enable news
occ app:enable notes
occ app:enable notify_push
occ app:enable spreed
occ app:enable tasks

# php-fpm

cp '/etc/php/php.ini' '/etc/php/php-fpm.ini'

sed 's/;zend_extension=opcache/zend_extension=opcache/' -i '/etc/php/php-fpm.ini'
sed '/\[opcache\]/a opcache.enable = 1\nopcache.interned_strings_buffer = 8\nopcache.max_accelerated_files = 10000\nopcache.memory_consumption = 128\nopcache.save_comments = 1\nopcache.revalidate_freq = 1\n' -i '/etc/php/php-fpm.ini'

echo "${php_config_addtions}" >> '/etc/php/php-fpm.ini'

chmod 644 '/etc/php/php-fpm.ini'

## nextcloud.conf pool file
if [[ -f '/etc/php/php-fpm.d/nextcloud.conf' ]]; then
	mv '/etc/php/php-fpm.d/nextcloud.conf' '/etc/php/php-fpm.d/nextcloud.conf_old'
fi

cp './nextcloud.conf' '/etc/php/php-fpm.d/nextcloud.conf'
chmod 644 '/etc/php/php-fpm.d/nextcloud.conf'

mkdir -p '/var/log/php-fpm/access'

# disable some default configuration
mv '/etc/php/php-fpm.d/www.conf' '/etc/php/php-fpm.d/www.conf.package'
echo '; This file was disabled by arch-server-scripts' > '/etc/php/php-fpm.d/www.conf'

# Modify, enable and start the systemd unit
mkdir -p '/etc/systemd/system/php-fpm.service.d'
cp './php-fpm_override.conf' '/etc/systemd/system/php-fpm.service.d/override.conf'

echo
echo ">>> Enableing and starting php-fpm.service..."
systemctl enable --now php-fpm.service


# Caddy web server

echo
echo ">>> IMPORTANT: You need to manually update '/usr/share/webapps/nextcloud/caddy/Caddyfile' to"
echo ">>> reflect your desired domains. By default, it will only serve unencrypted http on port 80"
echo ">>> on localhost."
cp -r './caddy' '/usr/share/webapps/nextcloud'
cp './caddy-nextcloud.service' '/usr/lib/systemd/system'

## Enable and start the systemd unit
systemctl enable --now caddy-nextcloud.service


systemctl enable --now nextcloud-app-notify_push.service

# Return to the previous working directory
cd "${__OLD_DIR}" || exit 2
