#!/usr/bin/env bash

set -e -x

[ -f published-stemcell/version ] || exit 1

echo "$(cat published-stemcell/version).0.0" > semver
