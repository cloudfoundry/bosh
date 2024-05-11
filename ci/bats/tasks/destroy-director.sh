#!/usr/bin/env bash
set -eu

echo "Removing '${HOME}/.bosh' so it can be paved over with 'director-state/.bosh'"
rm -rf "${HOME}/.bosh"
mv director-state/.bosh "${HOME}/"

mv bosh-cli/alpha-bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

state_path() { bosh-cli int director-state/director.yml --path="$1" ; }

function get_bosh_environment {
  if [[ -z $(state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null) ]]; then
    state_path /instance_groups/name=bosh/networks/name=default/static_ips/0 2>/dev/null
  else
    state_path /instance_groups/name=bosh/networks/name=public/static_ips/0 2>/dev/null
  fi
}

export BOSH_CLIENT="admin"
BOSH_CLIENT_SECRET=$(bosh-cli int director-state/director-creds.yml --path /admin_password)
BOSH_ENVIRONMENT=$(get_bosh_environment)
BOSH_CA_CERT=$(bosh-cli int director-state/director-creds.yml --path /director_ssl/ca)
export BOSH_ENVIRONMENT
export BOSH_CA_CERT
export BOSH_CLIENT_SECRET

set +e

bosh-cli deployments --column name --json | jq -r ".Tables[0].Rows[].name" | xargs -n1 -I % bosh-cli -n -d % delete-deployment
bosh-cli clean-up -n --all
bosh-cli delete-env -n director-state/director.yml -l director-state/director-creds.yml
