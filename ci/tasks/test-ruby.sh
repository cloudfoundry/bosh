#!/usr/bin/env bash

set -euxo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
build_dir="${script_dir}/../../.."
release_dir="${build_dir}/bosh-src"
stemcell="${build_dir}/stemcell/stemcell.tgz"

echo "-----> $(date): Creating a new release"
bosh create-release \
  --tarball "${build_dir}/bosh-release.tgz" \
  --dir "${release_dir}" \
  --force

echo "-----> $(date): Starting BOSH"
source start-bosh

source /tmp/local-bosh/director/env

echo "-----> $(date): Uploading release to director"
bosh upload-release "${build_dir}/bosh-release.tgz"

echo "-----> $(date): Uploading stemcell"
bosh -n upload-stemcell "${stemcell}"

echo "-----> $(date): Deploy test deployment"
bosh -n -d test deploy "${release_dir}/ci/manifests/test-ruby.yml" -v ruby-test-package=director-ruby-${RUBY_VERSION}-test

echo "-----> $(date): Run test errand"
bosh -n -d test run-errand ruby-thin-server

echo "-----> $(date): Done"
