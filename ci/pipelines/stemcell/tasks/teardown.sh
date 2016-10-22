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

if [ -d "${input_dir}/.bosh" ]; then
  # reuse compiled packages
  cp -r ${input_dir}/.bosh $HOME/
fi

pushd ${input_dir} > /dev/null
  # configuration
  export BOSH_DIRECTOR_IP=$DIRECTOR_IP
  export BOSH_USER=$BOSH_USER
  export BOSH_PASSWORD=$BOSH_PASSWORD

  echo "deleting existing BOSH Director VM..."
  $bosh_cli -n delete-env director.yml
popd
