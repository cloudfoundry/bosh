#!/usr/bin/env bash

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

env | sort

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION
cd bosh-src

#git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
#git config --global user.name "bosh-ci"

echo "--- Starting bundle install in `pwd` @ `date` ---"
if [ -f .bundle/config ]; then
  echo ".bundle/config:"
  cat .bundle/config
fi


echo "Starting MySQL..."
sudo service mysql start

echo "Starting PostgreSQL..."
sudo service postgresql start

set +e

bundle install
echo "--- Starting rake task @ `date` ---"
bundle exec rake "$@"

exitcode=$?

echo "Stopping PostgreSQL..."
sudo service postgresql stop

echo "Stopping MySQL..."
sudo service mysql stop

exit $exitcode
