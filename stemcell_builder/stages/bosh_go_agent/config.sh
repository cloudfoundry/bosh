#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

agent_go_path=$assets_dir/go/src/github.com/cloudfoundry/
mkdir -p $agent_go_path
cp -rvH $agent_src_dir $agent_go_path