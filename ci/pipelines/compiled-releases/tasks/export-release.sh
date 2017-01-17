#!/bin/sh

set -eux

export BOSH_ENVIRONMENT=`bosh-cli int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT="$(bosh-cli int director-state/director-creds.yml --path /director_ssl/ca)"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh-cli int director-state/director-creds.yml --path /admin_password`
export BOSH_DEPLOYMENT=compilation

#
# stemcell metadata/upload
#

tar -xzf stemcell/*.tgz $( tar -tzf stemcell/*.tgz | grep 'stemcell.MF' )
STEMCELL_OS=$( grep -E '^operating_system: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )
STEMCELL_VERSION=$( grep -E '^version: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )

bosh-cli -n upload-stemcell stemcell/*.tgz

#
# release metadata/upload
#

cd release
tar -xzf *.tgz $( tar -tzf *.tgz | grep 'release.MF' )
RELEASE_NAME=$( grep -E '^name: ' release.MF | awk '{print $2}' | tr -d "\"'" )
RELEASE_VERSION=$( grep -E '^version: ' release.MF | awk '{print $2}' | tr -d "\"'" )

bosh-cli -n upload-release *.tgz
cd ../

#
# compilation deployment
#

cat > manifest.yml <<EOF
---
name: $BOSH_DEPLOYMENT
releases:
- name: "$RELEASE_NAME"
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

bosh-cli -n -d $BOSH_DEPLOYMENT deploy manifest.yml
bosh-cli -d $BOSH_DEPLOYMENT export-release $RELEASE_NAME/$RELEASE_VERSION $STEMCELL_OS/$STEMCELL_VERSION

mv *.tgz compiled-release/$( echo *.tgz | sed "s/\.tgz$/-$( date -u +%Y%m%d%H%M%S ).tgz/" )
sha1sum compiled-release/*.tgz

#
# cleanup
#

bosh-cli -n -d $BOSH_DEPLOYMENT delete-deployment
