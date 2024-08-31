#!/usr/bin/env bash
set -eu -o pipefail

cd bosh-src/src/brats/

golangci-lint run ./...
