#!/usr/bin/env bash


fly -t production set-pipeline -p bosh:261.x \
  -c ci/pipeline.yml \
  --load-vars-from <(lpass show -G "bosh concourse secrets" --notes) \
  -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
