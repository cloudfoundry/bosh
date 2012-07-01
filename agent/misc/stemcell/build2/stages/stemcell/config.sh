#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ -z "${ruby_bin:-}" ]
then
  ruby_bin="ruby"
fi

persist_value stemcell_name
persist_value stemcell_version
persist_value stemcell_infrastructure
persist_value bosh_protocol_version
persist_value ruby_bin
