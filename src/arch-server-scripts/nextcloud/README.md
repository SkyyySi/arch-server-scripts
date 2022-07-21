# Nextcloud install scripts for Arch Linux

## Summary

This script will install Nextcloud on your server. It will ask you for
credentials, so do not let this script run unattended!

## Project status

This script can be deployed and it should "just work". Everything I tested
worked flawlessly, including a minor version upgrade as well as an upgrade
of some apps (from the cli using `pacman` as well as from the web interface).
That being said, as of now, this script does make some assumptions about
your system that may not necessarily be met. Primarily, I would advise agains
using this if you already use Redis, and you probably also don't want to use
this script if you deploy a php-fpm app already. Also, it appears as though
running `occ maintenance:install [...]` will remove the option from running
it again until the previous installation was properly removed and cleaned up,
so if you already have a half-broken Nextcloud install and you want to run this
script to "fix" it for you: Don't.

In the future, this script should be updated to better work around existing
environments, by providing all needed files itself (rather than patching ones
that come with their corrosponding packages) and maybe also moving everything
into an isolated, consistent directory, leaving everything untouched that doesn't
*have* to be touched. Perhaps it will be moved into a directory structure such as:

```
/opt/arch-server-scripts/
  > etc/
    > caddy/
      > Caddyfile
    > php/
      > php-fpm.ini
    > webapps/nextcloud/
      > php.ini
      > config/
        > config.php
  > var/
    > lib/
      > [...]
    > log/
      > [...]
```

## Description

This will install a Nextcloud instance with the following setup:

- Database: `MySQL` (by default MariaDB)
  - DB name: `nextcloud`
  - DB user: `nextcloud`
- Application server: `php-fpm`
- Web server: `caddy`
- Memcache: `redis`
- Additional Nextcloud apps and services:
  - bookmarks
  - calendar
  - contacts
  - deck
  - mail
  - news
  - notes
  - spreed
  - tasks
  - notify_push

## Dependencies

All dependencies will be installed automatically. As of now, this script
does not require `paru` to be installed.
