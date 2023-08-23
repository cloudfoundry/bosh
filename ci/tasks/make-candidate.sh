#!/usr/bin/env bash

set -e

export ROOT_PATH=$PWD

mv bosh-cli/alpha-bosh-cli-*-linux-amd64 bosh-cli/bosh-cli
export GO_CLI_PATH=$ROOT_PATH/bosh-cli/bosh-cli
chmod +x $GO_CLI_PATH

cd bosh-src

$GO_CLI_PATH create-release --tarball=../release/bosh-dev-release.tgz --timestamp-version --force
