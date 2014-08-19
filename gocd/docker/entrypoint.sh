#!/bin/bash

set -e
set -x

# run mysql as root (NOPASSWD recommended)
echo "Starting MySQL..."
sudo /etc/init.d/mysql start

echo "Starting PostgreSQL..."
pg_ctl start -l /var/log/postgresql/server.log

[ -d /opt/bosh ] && sudo chown -R ubuntu:ubuntu /opt/bosh

set +e

$@
exitcode=$?

echo "Stopping PostgreSQL..."
pg_ctl stop

echo "Stopping MySQL..."
sudo /etc/init.d/mysql stop

exit $exitcode
