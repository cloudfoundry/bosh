#!/usr/bin/env bash

set -eu

cat > director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
EOF

mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

bosh-cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/vsphere/cpi.yml \
  --vars-store director-creds.yml \
  -v director_name=stemcell-smoke-tests-director \
  --vars-env "BOSH" > director.yml

bosh-cli create-env director.yml -l director-creds.yml

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`bosh-cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`bosh-cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh-cli int director-creds.yml --path /admin_password`

bosh-cli -n update-cloud-config bosh-deployment/vsphere/cloud-config.yml -l director-creds.yml

mv $HOME/.bosh director-state/
mv director.yml director-creds.yml director-state.json director-state/
