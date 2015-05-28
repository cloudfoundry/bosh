#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

go_path=$assets_dir/go/src/github.com/cloudfoundry/
mkdir -p $go_path
cp -rvH $agent_src_dir $go_path
cp -rvH $davcli_src_dir $go_path
