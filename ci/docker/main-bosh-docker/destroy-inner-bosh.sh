#!/usr/bin/env bash

set -eu

cd /usr/local/bosh-deployment

local_bosh_dir="/tmp/local-bosh/director"
inner_bosh_dir="/tmp/inner-bosh/director"

if [ ! -e "${inner_bosh_dir}/bosh" ]; then
  exit
fi

source "${local_bosh_dir}/env"

"${inner_bosh_dir}/bosh" deployments --column=name \
  | awk '{ print $1 }' \
  | xargs -n1 -I {} -- "${inner_bosh_dir}/bosh" -n -d {} delete-deployment --force

bosh -n delete-deployment -d bosh

rm -fr "${inner_bosh_dir}"
