#!/usr/bin/env bash

source /etc/profile.d/chruby.sh
chruby 2.1.7

set -e

function cp_artifacts {
  mv $HOME/.bosh director-state/
  cp director.yml director-creds.yml director-state.json director-state/
}

trap cp_artifacts EXIT

: ${BAT_INFRASTRUCTURE:?}

mv bosh-cli/alpha-bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

bosh-cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/$BAT_INFRASTRUCTURE/cpi.yml \
  -o bosh-deployment/misc/powerdns.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -o bosh-src/ci/bats/ops/remove-health-monitor.yml \
  -o bosh-deployment/local-bosh-release.yml \
  -v dns_recursor_ip=8.8.8.8 \
  -v director_name=bats-director \
  -v local_bosh_release=$(realpath bosh-release/*.tgz) \
  --vars-file <( bosh-src/ci/bats/iaas/$BAT_INFRASTRUCTURE/director-vars ) \
  $DEPLOY_ARGS \
  > director.yml

bosh-cli create-env \
  --state director-state.json \
  --vars-store director-creds.yml \
  director.yml
