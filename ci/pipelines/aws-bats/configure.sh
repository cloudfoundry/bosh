#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:aws-ubuntu-bats \
  -c pipeline.yml \
  -l <(lpass show -G "bosh:aws-ubuntu-bats concourse secrets" --notes)
