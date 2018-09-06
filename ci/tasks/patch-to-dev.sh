#!/usr/bin/env bash

set -eux

export FULL_VERSION=$(cat version/version)

export ROOT_PATH=$PWD
BOSH_MASTER=$PWD/bosh-master-bumped-dev-version

git clone ./bosh-master-with-final $BOSH_MASTER

pushd "${BOSH_MASTER}"
  git status

  sed -i "s/\['version'\] = ..*/['version'] = '$FULL_VERSION+dev'/" jobs/director/templates/director.yml.erb
  sed -i "s/\['version'\])\.to eq..*/['version']).to eq('$FULL_VERSION+dev')/" spec/director.yml.erb_spec.rb

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Bump version $FULL_VERSION+dev via concourse"
popd
