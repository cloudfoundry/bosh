#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.2

initver=$(cat setup-director/bosh-init/version)
initexe="${PWD}/setup-director/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

director_manifest_file=${PWD}/setup-director/deployment/director-manifest.yml
echo "deleting existing BOSH Director VM..."
$initexe delete ${director_manifest_file}
