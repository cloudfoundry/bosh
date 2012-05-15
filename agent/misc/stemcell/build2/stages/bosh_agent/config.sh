#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ -z "${bosh_agent_src_dir:-}" ]
then
  # Use relative path to the BOSH agent
  bosh_agent_src_dir=$(readlink -nf $base_dir/../../..)
fi

ruby="ruby -I$bosh_agent_src_dir/lib"
bosh_agent_src_version=$($ruby -r"agent/version" -e"puts Bosh::Agent::VERSION")

assert_dir bosh_agent_src_dir
assert_not_empty bosh_agent_src_version
