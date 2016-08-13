#!/usr/bin/env bash

set -e -x

# allow to specify custom env variable
published_version=$BOSH_PUBLISHED_STEMCELL_VERSION

if [[ ! "$published_version" ]]; then
	[ -f published-stemcell/version ] || exit 1
	published_version=$(cat published-stemcell/version)
fi

# check for minor (only supports x and x.x)
if [[ "$published_version" == *.* ]]; then
	echo "${published_version}.0" > version/semver # fill in patch
else
	echo "${published_version}.0.0" > version/semver # fill in minor.patch
fi
