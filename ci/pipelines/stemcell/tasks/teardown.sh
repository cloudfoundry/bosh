#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
input_dir=$(realpath director-state/)
bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

if [ ! -e "${input_dir}/director-state.json" ]; then
  echo "director-state.json does not exist, skipping..."
  exit 0
fi

pushd ${input_dir} > /dev/null
  # configuration
  echo "deleting existing BOSH Director VM..."
  $bosh_cli -n delete-env director.yml
popd
