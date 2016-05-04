#!/usr/bin/env bash

set -e -x

[ -f published-stemcell/version ] || exit 1

published_version=$(cat published-stemcell/version)

# check for minor (only supports x and x.x)
if [[ "$published_version" == *.* ]]; then
	echo "${published_version}.0" > semver # fill in patch
else
	echo "${published_version}.0.0" > semver # fill in minor.patch
fi
