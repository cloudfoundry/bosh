#!/bin/bash

set -e
set -x

echo "Starting $DB..."

sudo mkdir -p /var/postgres && chown vcap:vcap /var/postgres
sudo mkdir -p /var/run/postgresql && chown vcap:vcap /var/run/postgresql
sudo mkdir -p /var/log/postgresql && chown vcap:vcap /var/log/postgresql
sudo pg_ctl init && pg_ctl start -l /var/log/postgresql/server.log && sleep 4 && createuser -U vcap --superuser postgres && createdb -U vcap && pg_ctl stop

case "$DB" in
  mysql)
    sudo service mysql start
    ;;
  postgresql)
#    su - vcap # TODO: remove this once we can run as non-privileged
    pg_ctl start -l /var/log/postgresql/server.log
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
#    su - vcap # TODO: remove this once we can run as non-privileged
    pg_ctl stop
    ;;
esac

exit $exitcode
