#!/usr/bin/env bash

occ maintenance:install \
	--database="mysql" \
	--database-name="nextcloud" \
	--database-host="localhost:/run/mysqld/mysqld.sock" \
	--database-user="nextcloud" \
	--database-pass="next" \
	--admin-pass="123456" \
	--admin-email="rasti.b@proton.me" \
	--data-dir="/var/lib/nextcloud/data"
