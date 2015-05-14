#!/bin/bash

set -e
set -x

echo "Starting $DB..."

case "$DB" in
  mysql)
    sudo service mysql start
    ;;
  postgresql)
    su - postgres -c "ls -l"
    su - postgres -c "source $(dirname $0)/environment.sh ; initdb -U postgres -D $PGDATA ; pg_ctl start -l $PGLOGS/server.log"
    ;;
  *)
    echo $"Usage: $0 {mysql|postgresql}"
    exit 1
esac

set +e
$@
exitcode=$?

echo "Stopping $DB..."
case "$DB" in
  mysql)
    sudo service mysql stop
    ;;
  postgresql)
    su - postgres -c "pg_ctl stop"
    ;;
esac

exit $exitcode
