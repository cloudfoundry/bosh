#!/usr/bin/env bash

main() {
  set -eu

  source start-bosh
  source /tmp/local-bosh/director/env

  tar -xzf release/*.tgz $( tar -tzf release/*.tgz | grep 'release.MF' )
  local RELEASE_NAME=$( grep -E '^name: ' release.MF | awk '{print $2}' | tr -d "\"'" )
  local RELEASE_VERSION=$( grep -E '^version: ' release.MF | awk '{print $2}' | tr -d "\"'" )
  local RELEASE_TARBALL=$( echo release/*.tgz )

  tar -xzf stemcell/*.tgz $( tar -tzf stemcell/*.tgz | grep 'stemcell.MF' )
  local STEMCELL_OS=$( grep -E '^operating_system: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )
  local STEMCELL_VERSION=$( grep -E '^version: ' stemcell.MF | awk '{print $2}' | tr -d "\"'" )

  bosh -n upload-stemcell stemcell/*.tgz
  bosh -n upload-release $RELEASE_TARBALL

  bosh -n -d compilation deploy bosh-src/ci/assets/compilation-manifest.yml \
    -v release_name="$RELEASE_NAME" \
    -v release_version="'$RELEASE_VERSION'" \
    -v stemcell_os="$STEMCELL_OS" \
    -v stemcell_version="'$STEMCELL_VERSION'"

  bosh -d compilation export-release $RELEASE_NAME/$RELEASE_VERSION $STEMCELL_OS/$STEMCELL_VERSION

  mv *.tgz compiled-release/$(echo *.tgz | sed "s/${STEMCELL_VERSION}-.*\.tgz/${STEMCELL_VERSION}.tgz/")
}

main "$@"
