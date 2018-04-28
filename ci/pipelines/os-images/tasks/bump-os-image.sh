#!/bin/bash

set -eu

function version_id() {
  local s3_tarball=${1?'s3 resource input required.'}

  cat $s3_tarball/version
}

function git_sha() {
  local repo=${1?'GitHub repository path is required.'}

  pushd $repo > /dev/null
    git rev-parse --verify HEAD
  popd > /dev/null
}

function git_commit() {
  local repo=${1?'GitHub repository path is required.'}

  pushd $repo
    git add src/bosh-stemcell/os_image_versions.json
    git config user.name "CI Bot"
    git config user.email "ci@localhost"
    git commit -m "Bump OS image"
  popd
}

function main() {
  local bosh_linux_stemcell_builder_sha="$( git_sha bosh-src )"
  local ubuntu_trust_tarball_version_id="$( version_id ubuntu-trusty-tarball )"
  local centos_7_tarball_version_id="$( version_id centos-7-tarball )"

  pushd bosh-src/src/bosh-stemcell
    jq -n --arg centos_id "$( version_id ../../../centos-7-tarball )" \
      --arg ubuntu_id "$( version_id ../../../ubuntu-trusty-tarball )" \
      --arg git_sha "$( git_sha ../../../bosh-src )" \
      '{
        "git-sha": $git_sha,
        "bosh-centos-7-os-image.tgz": $centos_id,
        "bosh-ubuntu-trusty-os-image.tgz": $ubuntu_id
      }' > os_image_versions.json
  popd

  rsync -avzp bosh-src/ bosh-src-push
  git_commit bosh-src-push
}

main
