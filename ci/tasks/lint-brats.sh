#!/usr/bin/env bash
set -eu -o pipefail

cd bosh/src/brats/

golangci-lint run ./...
