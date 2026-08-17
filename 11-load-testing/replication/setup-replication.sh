#!/usr/bin/env sh
# Configures file-position replication from mysql-primary to mysql-standby.
# The service stays alive after setup so Docker Compose can track it with a healthcheck.

set -eu

primary_host="${MYSQL_PRIMARY_HOST:-mysql-primary}"
standby_host="${MYSQL_STANDBY_HOST:-mysql-standby}"
root_password="${MYSQL_ROOT_PASSWORD:-rootpass}"
replication_user="${REPLICATION_USER:-replicator}"
replication_password="${REPLICATION_PASSWORD:-replpass}"

primary_mysql() {
  mysql --protocol=tcp -h "${primary_host}" -uroot -p"${root_password}" "$@"
}

standby_mysql() {
  mysql --protocol=tcp -h "${standby_host}" -uroot -p"${root_password}" "$@"
}

wait_for_mysql() {
  host="$1"
  for attempt in $(seq 1 60); do
    if mysql --protocol=tcp -h "${host}" -uroot -p"${root_password}" -e "SELECT 1" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "MySQL did not become ready on ${host}" >&2
  exit 1
}

wait_for_mysql "${primary_host}"
wait_for_mysql "${standby_host}"

primary_mysql -e "
CREATE USER IF NOT EXISTS '${replication_user}'@'%' IDENTIFIED BY '${replication_password}';
GRANT REPLICATION SLAVE ON *.* TO '${replication_user}'@'%';
FLUSH PRIVILEGES;
"

status="$(primary_mysql -N -e "SHOW BINARY LOG STATUS;" 2>/dev/null || primary_mysql -N -e "SHOW MASTER STATUS;")"
source_file="$(printf '%s\n' "${status}" | awk 'NR == 1 {print $1}')"
source_position="$(printf '%s\n' "${status}" | awk 'NR == 1 {print $2}')"

if [ -z "${source_file}" ] || [ -z "${source_position}" ]; then
  echo "Could not read primary binary log coordinates." >&2
  exit 1
fi

standby_mysql -e "STOP REPLICA;" >/dev/null 2>&1 || true
standby_mysql -e "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
standby_mysql -e "RESET REPLICA ALL;" >/dev/null 2>&1 || true
standby_mysql -e "
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${primary_host}',
  SOURCE_PORT=3306,
  SOURCE_USER='${replication_user}',
  SOURCE_PASSWORD='${replication_password}',
  SOURCE_LOG_FILE='${source_file}',
  SOURCE_LOG_POS=${source_position},
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;
"

for attempt in $(seq 1 60); do
  replica_status="$(standby_mysql -e "SHOW REPLICA STATUS\\G" 2>/dev/null || true)"
  if printf '%s\n' "${replica_status}" | grep -q "Replica_IO_Running: Yes" &&
     printf '%s\n' "${replica_status}" | grep -q "Replica_SQL_Running: Yes"; then
    touch /tmp/replication-ready
    echo "Replication is running from ${primary_host} to ${standby_host}."
    while true; do
      sleep 3600
    done
  fi
  sleep 2
done

standby_mysql -e "SHOW REPLICA STATUS\\G" || true
echo "Replication did not become healthy." >&2
exit 1
