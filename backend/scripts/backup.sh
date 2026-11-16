#!/bin/sh
set -eu
umask 077
set -C
# 운영 스택이 실행된 뒤 backend 디렉터리에서 사용한다.
mkdir -p backups
file="backups/pickwise-$(date -u +%Y%m%dT%H%M%SZ).sql"
tmp="$file.partial"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
docker compose -f compose.production.yaml exec -T mysql sh -c \
  'MYSQL_PWD=$(cat /run/secrets/db_password) exec mysqldump --single-transaction --no-tablespaces -u pickwise pickwise' > "$tmp"
test -s "$tmp"
mv "$tmp" "$file"
printf 'Backup created: %s\n' "$file"
