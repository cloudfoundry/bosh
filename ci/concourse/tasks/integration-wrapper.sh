#!/bin/bash

set -e
set -x

echo "Starting $DB..."
sudo service $DB start

set +e
$@
exitcode=$?

echo "Stopping $DB..."
sudo service $DB stop

exit $exitcode
