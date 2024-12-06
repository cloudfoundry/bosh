#!/usr/bin/env bash
set -euo pipefail

start-bosh

source /tmp/local-bosh/director/env

stemcell_url="$(bosh interpolate /usr/local/bosh-deployment/warden/cpi.yml --path /name=stemcell/value/url)"
bosh upload-stemcell "${stemcell_url}"

cat <<EOF > /tmp/defaults.yml
- type: replace
  path: /name?
  value: rendering_test
- type: replace
  path: /stemcells?/alias=default
  value:
    alias: default
    version: latest
    os: $(echo "${stemcell_url}" | grep -oE "ubuntu-[^-]+")
- type: replace
  path: /update?
  value:
    canaries: 1
    max_in_flight: 1
    canary_watch_time: 1000-30000
    update_watch_time: 1000-30000
- type: replace
  path: /instance_groups/0/stemcell?
  value: default
- type: replace
  path: /instance_groups/0/vm_type?
  value: default
- type: replace
  path: /instance_groups/0/networks?
  value: [{name: default}]
- type: replace
  path: /instance_groups/0/azs?
  value: [z1]
EOF

export BOSH_DEPLOYMENT="rendering_test"

pushd release > /dev/null
  if "${DEV_RELEASE}" == "true"; then
    bosh create-release --force
  fi
  bosh upload-release
popd

for manifest in "${MANIFEST_FOLDER}"/*.yml; do
  bosh -n deploy --dry-run \
    -o /tmp/defaults.yml \
    "${manifest}"
done
