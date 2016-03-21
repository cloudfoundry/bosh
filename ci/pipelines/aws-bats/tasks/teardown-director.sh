#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.2

initexe=${PWD}/bosh-init/bosh-init-*-linux-amd64
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

director_manifest_file=${PWD}/setup-director-output/deployment/director-manifest.yml
echo "deleting existing BOSH Director VM..."
$initexe delete ${director_manifest_file}
