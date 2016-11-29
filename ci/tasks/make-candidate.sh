#!/usr/bin/env bash

set -e

export version=$(cat candidate-version/version)

cd bosh-src

sed -i -E "s/VERSION = .+/VERSION = '$version'/" $( find src -name version.rb )

bosh create-release --version="$version" --tarball --timestamp --force

mv dev_releases/bosh/*.tgz ../../release/
