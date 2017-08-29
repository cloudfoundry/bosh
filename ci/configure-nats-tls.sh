#!/usr/bin/env bash

set -eu

fly -t production set-pipeline -p bosh-nats-tls \
    -c ci/pipeline-nats-tls.yml \
    --load-vars-from <(lpass show -G "bosh nats tls concourse secrets" --notes) \
    -l <(lpass show --note "bats-concourse-pool:vsphere secrets")
