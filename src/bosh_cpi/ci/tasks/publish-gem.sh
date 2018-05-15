#!/usr/bin/env bash

set -e

: ${RUBYGEMS_API_KEY:?}
: ${RUBY_VERSION:="2.3.1"}

version="$( cat version-semver/version )"

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

cat << EOF > ~/.gem/credentials
---
:rubygems_api_key: ${RUBYGEMS_API_KEY}
EOF
chmod 0600 ~/.gem/credentials

pushd bosh-cpi-ruby-gem
  git clean -xfd
  echo "${version}" > version
  gem build *.gemspec
  gem push bosh_cpi-*.gem
popd
