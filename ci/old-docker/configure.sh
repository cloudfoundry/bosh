#!/bin/bash

cd "$( dirname "${BASH_SOURCE[0]}" )"

fly -t bosh-ecosystem set-pipeline \
  -p bosh-docker-images \
  -c pipeline.yml 