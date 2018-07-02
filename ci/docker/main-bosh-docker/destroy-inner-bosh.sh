#!/usr/bin/env bash

set -eu

cd ${BOSH_DEPLOYMENT_PATH}

inner_bosh_dir="/tmp/inner-bosh/director"

if [ ! -e "${inner_bosh_dir}/bosh" ]; then
  exit
fi

"${inner_bosh_dir}/bosh" deployments --column=name \
  | awk '{ print $1 }' \
  | xargs -n1 -I {} -- "${inner_bosh_dir}/bosh" -n -d {} delete-deployment --force

bosh -n delete-deployment -d bosh

rm -fr "${inner_bosh_dir}"
