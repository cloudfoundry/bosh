#!/usr/bin/env bash

set -e

function cp_artifacts {
  rm -rf director-state/.bosh cache-dot-bosh-dir/.bosh
  cp -R "${HOME}/.bosh" director-state/
  cp -R "${HOME}/.bosh" cache-dot-bosh-dir/
  cp director.yml director-creds.yml director-state.json director-vars.json director-state/
}

function restore_state {
  rm -rf "${HOME}/.bosh"
  if [[ -e director-state/director-state.json ]]; then
    # restore state from a previous deploy
    cp -R director-state/.bosh "${HOME}"
  else
    # concourse task cache if we don't have recent state
    cp -R cache-dot-bosh-dir/.bosh "${HOME}"
  fi
  cp director-state/director-* .
}

trap cp_artifacts EXIT

: ${BAT_INFRASTRUCTURE:?}

mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

if [[ -e director-state/director-state.json ]]; then
  echo "Using existing director-state for upgrade"
  restore_state
fi

"bosh-ci/ci/bats/iaas/${BAT_INFRASTRUCTURE}/director-vars" > director-vars.json

bosh-cli interpolate bosh-deployment/bosh.yml \
  -o "bosh-deployment/${BAT_INFRASTRUCTURE}/cpi.yml" \
  -o bosh-deployment/jumpbox-user.yml \
  -o bosh-deployment/local-bosh-release-tarball.yml \
  -v director_name=bats-director \
  -v local_bosh_release="$(realpath bosh-release/*.tgz)" \
  --vars-file director-vars.json \
  $DEPLOY_ARGS \
  > director.yml

bosh-cli create-env \
  --state director-state.json \
  --vars-store director-creds.yml \
  director.yml

cat bosh-release/version
