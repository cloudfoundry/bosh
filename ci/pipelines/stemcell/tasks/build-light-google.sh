#!/bin/bash

set -e

: ${OS_NAME:?}
: ${OS_VERSION:?}
: ${BUCKET_NAME:?}

# inputs
stemcell_dir="$PWD/stemcell"
version_dir="$PWD/version"

# outputs
light_stemcell_dir="$PWD/light-stemcell"
raw_stemcell_dir="$PWD/raw-stemcell"

echo "Creating light stemcell..."

BUILD_NUMBER=$( cat "${version_dir}/number" | cut -f 1 -d "." )

mkdir working_dir
pushd working_dir
  tar xvf ${stemcell_dir}/*.tgz
  mv image "${raw_stemcell_dir}/bosh-stemcell-${BUILD_NUMBER}-google-kvm-${OS_NAME}-${OS_VERSION}-go_agent-raw.tar.gz"
  > image
  echo "  source_url: https://storage.googleapis.com/${BUCKET_NAME}/bosh-stemcell-${BUILD_NUMBER}-google-kvm-${OS_NAME}-${OS_VERSION}-go_agent-raw.tar.gz" >> stemcell.MF
  tar czvf "${light_stemcell_dir}/light-bosh-stemcell-${BUILD_NUMBER}-google-kvm-${OS_NAME}-${OS_VERSION}-go_agent.tgz" *
popd
