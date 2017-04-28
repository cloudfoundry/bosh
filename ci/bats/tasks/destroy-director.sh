#!/usr/bin/env bash

set -eu

mv director-state/.bosh $HOME/

state_path() { bosh-cli int director-state/director.yml --path="$1" ; }

function get_bosh_environment {
  if [[ -z $(state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null) ]]; then
    state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null
  else
    state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null
  fi
}

export BOSH_ENVIRONMENT=`get_bosh_environment`
export BOSH_CA_CERT=`bosh-cli int director-state/director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh-cli int director-state/director-creds.yml --path /admin_password`

set +e

bosh-cli deployments --column name | xargs -n1 -I % bosh-cli -n -d % delete-deployment
bosh-cli clean-up -n --all
bosh-cli delete-env -n director-state/director.yml -l director-state/director-creds.yml
