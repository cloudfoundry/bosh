#!/usr/bin/env bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ci_dir="${script_dir}/.."

main() {
  set -eu

  tar -xzf release/*.tgz "$( tar -tzf release/*.tgz | grep 'release.MF' )"
  tar -xzf stemcell/*.tgz "$( tar -tzf stemcell/*.tgz | grep 'stemcell.MF' )"

  export STEMCELL_OS=$( grep -E '^operating_system: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )
  local RELEASE_NAME=$( grep -E '^name: ' release.MF | awk '{print $2}' | tr -d "\"'" )
  local RELEASE_VERSION=$( grep -E '^version: ' release.MF | awk '{print $2}' | tr -d "\"'" )
  local RELEASE_TARBALL=$( echo release/*.tgz )
  local STEMCELL_VERSION=$( grep -E '^version: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )

  source start-bosh
  source /tmp/local-bosh/director/env

  bosh -n upload-stemcell stemcell/*.tgz
  bosh -n upload-release "${RELEASE_TARBALL}"

  bosh -n -d compilation deploy "${ci_dir}/ci/tasks/export-release/compilation-manifest.yml" \
    -v release_name="${RELEASE_NAME}" \
    -v release_version="'${RELEASE_VERSION}'" \
    -v stemcell_os="${STEMCELL_OS}" \
    -v stemcell_version="'${STEMCELL_VERSION}'"

  bosh -d compilation export-release "${RELEASE_NAME}/${RELEASE_VERSION}" "${STEMCELL_OS}/${STEMCELL_VERSION}"

  mv ./*.tgz "compiled-release/$(echo *.tgz | sed "s/${STEMCELL_VERSION}-.*\.tgz/${STEMCELL_VERSION}.tgz/")"
}

main "$@"
