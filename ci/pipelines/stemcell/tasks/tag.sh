#!/bin/sh

set -e
set -u

export VERSION=$( cat version/number | sed 's/\.0$//;s/\.0$//' )

git clone bosh-src bosh-src-tagged

cd bosh-src-tagged

git tag stable-$VERSION
