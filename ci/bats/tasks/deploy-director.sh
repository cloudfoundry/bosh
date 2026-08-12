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

# Name the director after its per-env terraform network (e.g. bosh-bats-noble,
# bosh-bats-jammy-fips, bosh-upgrade-postgres-noble). The GCP CPI derives VM
# network tags from the director name, so a per-env name keeps each job's
# `leftovers --filter <env name>` cleanup from reaching another job's VMs.
# Falls back to bats-director if metadata is unavailable.
director_name="bats-director"
if [[ -e environment/metadata ]]; then
  network_name="$(jq -r '.network // empty' environment/metadata)"
  if [[ -n "${network_name}" ]]; then
    director_name="${network_name}"
  fi
fi

# local-bosh-release-tarball.yml comes after $DEPLOY_ARGS so the release under
# test always wins: ops files such as bosh-deployment's
# misc/use-compiled-*-releases.yml replace /releases/name=bosh with a shipped
# release, which would otherwise silently swap out the candidate.
bosh-cli interpolate bosh-deployment/bosh.yml \
  -o "bosh-deployment/${BAT_INFRASTRUCTURE}/cpi.yml" \
  -o bosh-deployment/jumpbox-user.yml \
  -v director_name="${director_name}" \
  -v local_bosh_release="$(realpath bosh-release/*.tgz)" \
  --vars-file director-vars.json \
  $DEPLOY_ARGS \
  -o bosh-deployment/local-bosh-release-tarball.yml \
  > director.yml

# Belt and braces for the ordering above, so a future ops file cannot quietly
# deploy the wrong release.
release_url="$(bosh-cli int director.yml --path /releases/name=bosh/url)"
if [[ "${release_url}" != file://* ]]; then
  echo "FATAL: director would deploy ${release_url}, not the candidate under test." >&2
  echo "Something in DEPLOY_ARGS replaced /releases/name=bosh after local-bosh-release-tarball.yml." >&2
  exit 1
fi

bosh-cli create-env \
  --state director-state.json \
  --vars-store director-creds.yml \
  director.yml

version_file="bosh-release/version"
if [ -f "${version_file}" ]; then
  cat "${version_file}"
else
  echo "Version file '${version_file}' was not present"
fi
