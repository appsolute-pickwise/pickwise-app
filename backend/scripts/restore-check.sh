#!/bin/sh
set -eu
umask 077
test "$#" -eq 1 && test -s "$1" || { echo 'Usage: sh scripts/restore-check.sh snapshot.sql' >&2; exit 1; }
name="pickwise-restore-check-$$"
work=$(mktemp -d)
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM
printf 'MYSQL_ROOT_PASSWORD=%s\nMYSQL_DATABASE=pickwise\n' "$(openssl rand -hex 24)" > "$work/env"
docker run -d --name "$name" --network none --env-file "$work/env" mysql:8.4 >/dev/null
ready=false
for n in $(seq 1 60); do
  if docker exec "$name" sh -c 'MYSQL_PWD=$MYSQL_ROOT_PASSWORD mysql -u root -e "SELECT 1" pickwise' >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
[ "$ready" = true ] || { echo 'Temporary MySQL readiness failed' >&2; exit 1; }
docker exec -i "$name" sh -c 'MYSQL_PWD=$MYSQL_ROOT_PASSWORD exec mysql -u root pickwise' < "$1"
tables=$(docker exec "$name" sh -c 'MYSQL_PWD=$MYSQL_ROOT_PASSWORD mysql -u root -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"pickwise\""')
[ "$tables" -ge 6 ] || { echo 'Incomplete schema' >&2; exit 1; }
printf 'Restore verified in isolated MySQL: %s tables\n' "$tables"
