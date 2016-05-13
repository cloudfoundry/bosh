#!/bin/bash

set -e -x

source /etc/profile.d/chruby.sh
chruby 2.1


export BUNDLE_GEMFILE="${PWD}/bosh-src/Gemfile"

bundle install --local

bosh() {
  bundle exec bosh -n -t "${BOSH_DIRECTOR_ADDRESS}" "$@"
}

# login
bosh login "${BOSH_DIRECTOR_USERNAME}" "${BOSH_DIRECTOR_PASSWORD}"

cleanup() {
  bosh cleanup --all
}
trap cleanup EXIT

# bosh upload stemcell
pushd stemcell
  bosh upload stemcell ./*.tgz
popd

# bosh upload release (syslog)
pushd syslog-release
  bosh upload release ./*.tgz
popd

# build manifest
cat > "./deployment.yml" <<EOF
---
name: bosh-stemcell-smoke-tests
director_uuid: $(bosh status --uuid)

releases:
- name: syslog
  version: $(cat syslog-release/version)

stemcells:
- alias: default
  os: ubuntu-trusty
  version: $(cat stemcell/version)

update:
  canaries: 1
  max_in_flight: 10
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000

instance_groups:
- name: syslog_storer
  stemcell: default
  vm_type: default
  instances: 1
  networks:
  - {name: default}
  azs: [z1]
  jobs:
  - name: syslog_storer
    release: syslog
    properties:
      syslog:
        transport: tcp
        port: 514
- name: syslog_forwarder
  stemcell: default
  vm_type: default
  azs: [z1]
  instances: 1
  networks:
  - {name: default}
  jobs:
  - name: syslog_forwarder
    release: syslog
    consumes:
      syslog_storer: { from: syslog_storer }
EOF

cleanup() {
  bosh delete deployment bosh-stemcell-smoke-tests
  bosh cleanup --all
}

bosh -d ./deployment.yml deploy

# trigger auditd event
bosh -d ./deployment.yml ssh syslog_forwarder 0 'sudo modprobe -r floppy'
bosh -d ./deployment.yml ssh syslog_forwarder 0 'logger -t vcap some vcap message'

# check that syslog drain gets event
download_destination=$(mktemp -d -t)
bosh -d ./deployment.yml scp --download syslog_storer 0 /var/vcap/store/syslog_storer/syslog.log $download_destination

grep 'COMMAND=/sbin/modprobe -r floppy' $download_destination/syslog.log.syslog_storer. || ( echo "Syslog did not contain 'audit'!" ; exit 1 )
grep 'some vcap message' $download_destination/syslog.log.syslog_storer. || ( echo "Syslog did not contain 'vcap'!" ; exit 1 )
