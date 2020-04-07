#!/usr/bin/env bash

set -eu

source start-bosh
source /tmp/local-bosh/director/env

RELEASE_VERSION=$( cat version/version )

#
# stemcell metadata/upload
#

tar -xzf stemcell/*.tgz $( tar -tzf stemcell/*.tgz | grep 'stemcell.MF' )
STEMCELL_OS=$( grep -E '^operating_system: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )
STEMCELL_VERSION=$( grep -E '^version: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )

bosh -n upload-stemcell stemcell/*.tgz

#
# release metadata/upload
#

pushd bosh-src
  bosh -n upload-release releases/bosh/bosh-${RELEASE_VERSION}.yml
popd

#
# compilation deployment
#

cat > manifest.yml <<EOF
---
name: compilation
releases:
- name: bosh
  version: "$RELEASE_VERSION"
stemcells:
- alias: default
  os: "$STEMCELL_OS"
  version: "$STEMCELL_VERSION"
update:
  canaries: 1
  max_in_flight: 1
  canary_watch_time: 1000 - 90000
  update_watch_time: 1000 - 90000
instance_groups: []
EOF

bosh -n -d compilation deploy manifest.yml
bosh -d compilation export-release bosh/$RELEASE_VERSION $STEMCELL_OS/$STEMCELL_VERSION

mv *.tgz compiled-release/$(echo *.tgz | sed "s/${STEMCELL_VERSION}-.*\.tgz/${STEMCELL_VERSION}.tgz/")
sha1sum compiled-release/*.tgz
mkdir -p metalink-path
echo -n "github.com/cloudfoundry/bosh/bosh-${RELEASE_VERSION}/${STEMCELL_OS}-${STEMCELL_VERSION}/source.meta4" | tee metalink-path/file-path
