#!/usr/bin/env bash

set -eux

export FULL_VERSION=$(cat version/version)

export ROOT_PATH=$PWD
BOSH_SRC=$PWD/bosh-src
TARBALL_OUTPUT_DIR=$PWD/release-tarball

mkdir -p $TARBALL_OUTPUT_DIR

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

pushd $BOSH_SRC
  git status

  sed -i "s/\['version'\] = ..*/['version'] = '$FULL_VERSION'/" jobs/director/templates/director.yml.erb
  sed -i "s/\['version'\])\.to eq..*/['version']).to eq('$FULL_VERSION')/" spec/director.yml.erb_spec.rb
  sed -i "s/version: ..*/version: $FULL_VERSION/" jobs/director/templates/indicator.yml.erb

  git add -A
  git status

  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"

  git commit -m "Bump version $FULL_VERSION via concourse"

  $GO_CLI_PATH create-release --version $FULL_VERSION --tarball=$TARBALL_OUTPUT_DIR/tarball.tgz
popd
