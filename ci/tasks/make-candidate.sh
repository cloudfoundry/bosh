#!/usr/bin/env bash

set -e

export version=$(cat version/version)
export ROOT_PATH=$PWD

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

cd bosh-src

sed -i "s/\['version'\] = ..*/['version'] = '$version'/" jobs/director/templates/director.yml.erb
sed -i "s/version: ..*/version: $version/" jobs/director/templates/indicator.yml.erb

$GO_CLI_PATH create-release --tarball=../release/bosh-dev-release.tgz --timestamp-version --force
