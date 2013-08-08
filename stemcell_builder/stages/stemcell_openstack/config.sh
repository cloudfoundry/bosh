#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Find `ruby` in PATH if needed
if [ -z "${ruby_bin:-}" ]
then
  if which ruby >/dev/null
  then
    ruby_bin=$(which ruby)
  fi
fi

# Abort when $ruby_bin is empty
if [ -z "${ruby_bin:-}" ]
then
  echo "ruby_bin is empty"
  exit 1
fi

# Abort when $ruby_bin is not executable
if [ ! -x $ruby_bin ]
then
  echo "$ruby_bin is not executable"
  exit 1
fi

persist_value stemcell_name
persist_value stemcell_tgz
persist_value stemcell_version
persist_value stemcell_infrastructure
persist_value stemcell_hypervisor
persist_value bosh_protocol_version
persist_value ruby_bin