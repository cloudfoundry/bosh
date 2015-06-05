#!/usr/bin/env bash

set -e

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

source $(dirname $0)/environment.sh

cd bosh-src
if [ -f ".fly_exec" ] ; then
  source .fly_exec
fi
source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

env | sort

echo "--- Show git state in `pwd` @ `date` ---"
# optionally switch to branch (e.g., from 'fly execute')
if [ -z ${GIT_BRANCH+x} ] ; then
  git checkout $GIT_BRANCH
fi
echo " -> last commit..."
git log -1
echo "    ---"
echo " -> local changes (e.g., from 'fly execute')..."
git status
echo "    ---"

echo "--- Starting bundle install in `pwd` @ `date` ---"
if [ -f .bundle/config ] ; then
  echo ".bundle/config:"
  cat .bundle/config
fi
bundle install

echo "--- Starting rake task @ `date` ---"
bundle exec rake "$@"
