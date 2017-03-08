#!/usr/bin/env bash

set -eu

cat > director-creds.yml <<EOF
internal_ip: $BOSH_TARGET_IP
EOF

echo "$BOSH_private_key" > /tmp/private_key

bosh-cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/aws/cpi.yml \
  --vars-store director-creds.yml \
  -v region=us-east-1 \
  -v az=us-east-1a \
  -v default_key_name=compiled-release \
  -v default_security_groups=[bosh] \
  -v subnet_id=subnet-20d8bf56 \
  -v director_name=release-compiler \
  -v internal_cidr=10.0.2.0/24 \
  -v internal_gw=10.0.2.1 \
  --var-file private_key=/tmp/private_key \
  --vars-env "BOSH" > director.yml

bosh-cli create-env director.yml -l director-creds.yml

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`bosh-cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`bosh-cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh-cli int director-creds.yml --path /admin_password`

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

bosh-cli -n update-cloud-config /tmp/cloud-config

mv $HOME/.bosh director-state/
mv director.yml director-creds.yml director-state.json director-state/
