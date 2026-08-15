#!/usr/bin/env sh
# Periodic MySQL backup worker.
# It writes timestamped SQL dumps into /backups, which is a separate Docker volume.

set -eu

backup_once() {
  timestamp="$(date +%Y%m%d-%H%M%S)"
  target="/backups/${MYSQL_DATABASE}-${timestamp}.sql"

  echo "Creating backup: ${target}"
  mysqldump \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT:-3306}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    --single-transaction \
    --routines \
    --events \
    "${MYSQL_DATABASE}" > "${target}"

  echo "Backup complete: ${target}"
}

if [ "${INIT_BACKUP:-true}" = "true" ]; then
  backup_once
fi

while true; do
  sleep "${BACKUP_INTERVAL_SECONDS:-60}"
  backup_once
done

