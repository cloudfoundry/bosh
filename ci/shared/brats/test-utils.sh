#!/usr/bin/env bash
set -eu -o pipefail

bosh_repo_dir="$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)")"

pushd "${bosh_repo_dir}/src/brats/utils"
  go run github.com/onsi/ginkgo/v2/ginkgo \
    -r -v --race --timeout=24h \
    --randomize-suites --randomize-all \
    --focus="${FOCUS_SPEC:-}" \
    --nodes 1 \
    .
popd
