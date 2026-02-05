#!/usr/bin/env bash

set -e

pushd "${BOSH_DEPLOYMENT_PATH}" > /dev/null
  node_number=$1
  inner_bosh_dir="/tmp/inner-bosh/director"
  deployment_name="bosh"

  if [[ -n "$node_number" ]]; then
    inner_bosh_dir="/tmp/inner-bosh/director/${node_number}"
    deployment_name="bosh-$node_number"
  fi

  if [ ! -e "${inner_bosh_dir}/bosh" ]; then
    exit
  fi

  "${inner_bosh_dir}/bosh" deployments --column=name \
    | awk '{ print $1 }' \
    | xargs -n1 -I {} -- "${inner_bosh_dir}/bosh" -n -d {} delete-deployment --force

  bosh -n delete-deployment -d "$deployment_name"

  rm -fr "${inner_bosh_dir}"
popd > /dev/null
