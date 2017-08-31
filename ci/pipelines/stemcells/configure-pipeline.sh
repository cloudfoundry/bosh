#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
 -p bosh:stemcells:3312.x \
 -v stemcell-branch=3312.x \
 -v stemcell_version_key=bosh-stemcell/version-3312.x \
 -v stemcell_version_semver_bump=minor \
 -c ci/pipelines/stemcells/pipeline.yml \
 -l <(lpass show --note "concourse:production pipeline:bosh:stemcells:3312.x") \
 -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
