#!/usr/bin/env bash

set -eu

set +e
( cd stemcell; mv *.tgz stemcell.tgz )
set -e

sed \
  -e "s%{{access_key_id}}%$BOSH_INIT_ACCESS_KEY%g" \
  -e "s%{{secret_key_id}}%$BOSH_INIT_SECRET_KEY%g" \
  -e "s%{{bosh_username}}%$BOSH_USERNAME%g" \
  -e "s%{{bosh_password}}%$BOSH_PASSWORD%g" \
  -e "s%{{bosh_target_ip}}%$BOSH_TARGET_IP%g" \
  bosh-src/ci/pipelines/compiled-releases/tasks/bosh-init-template.yml \
  > bosh-init.yml

echo "$BOSH_SSH_TUNNEL_KEY" > ssh_tunnel_key
chmod 600 ssh_tunnel_key

bosh-init deploy bosh-init.yml

bosh -n target "https://$BOSH_TARGET_IP:25555"
bosh login "$BOSH_USERNAME" "$BOSH_PASSWORD"

#
# create/upload cloud config
#

cat > /tmp/cloud-config <<EOF
---
vm_types:
- name: default
  cloud_properties:
    instance_type: c4.large
    availability_zone: us-east-1a
    ephemeral_disk:
      size: 8192

networks:
- name: private
  subnets:
  - range: 10.0.2.0/24
    gateway: 10.0.2.1
    dns: [169.254.169.253]
    reserved: $BOSH_RESERVED_RANGES
    cloud_properties:
        subnet: "subnet-20d8bf56"

compilation:
  workers: 8
  reuse_compilation_vms: true
  vm_type: default
  network: private
EOF

bosh update cloud-config /tmp/cloud-config

mv $HOME/.bosh_init director-state/
mv bosh-init.yml bosh-init-state.json director-state/
