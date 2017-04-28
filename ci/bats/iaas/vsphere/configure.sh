#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:vsphere-bats \
  -c pipeline.yml \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets") \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells")

