#!/usr/bin/env bash
set -eu -o pipefail
set -x

output_dir="docker-build-context"

mkdir -p "${output_dir}"

cp -p -R \
  bosh-ci-dockerfiles/ci/dockerfiles/"${CONTAINER_CPI_TYPE}"/* \
  bosh-cli/bosh-cli-*-linux-amd64 \
  bosh-deployment \
  "${output_dir}"