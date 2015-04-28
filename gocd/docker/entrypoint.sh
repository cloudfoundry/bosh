#!/bin/bash

set -e
set -x

echo "Starting MySQL..."
sudo service mysql start

echo "Starting PostgreSQL..."
sudo service postgresql start

[ -d /opt/bosh ] && sudo chown -R ubuntu:ubuntu /opt/bosh

set +e

$@
exitcode=$?

echo "Stopping PostgreSQL..."
sudo service postgresql stop

echo "Stopping MySQL..."
sudo service mysql stop

exit $exitcode
