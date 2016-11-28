#!/bin/bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

env

if [ -z "${RHN_USERNAME:-}" -o -z "${RHN_PASSWORD:-}" ]; then
  echo "Environment variables RHN_USERNAME and RHN_PASSWORD are required for RHEL installation."
  exit 1
else
  echo "PERSISTING ENVIRONMENT TO ${settings_file}"
  persist RHN_USERNAME
  persist RHN_PASSWORD
fi
