#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
  -p bosh:stemcells -c ci/pipelines/stemcells/pipeline.yml \
  -l <(lpass show --note "concourse:production pipeline:bosh:stemcells") \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
