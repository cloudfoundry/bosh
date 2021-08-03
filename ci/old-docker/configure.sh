#!/bin/bash

cd "$( dirname "${BASH_SOURCE[0]}" )"

fly -t bosh-ecosystem set-pipeline \
  -p bosh-docker-images \
  -c pipeline.yml \
  --load-vars-from <(lpass show --note "bosh:docker-images concourse secrets")
