#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ -z "${bosh_agent_src_dir:-}" ]
then
  # Use relative path to the BOSH agent
  bosh_agent_src_dir=$(readlink -nf $base_dir/../bosh_agent)
fi

if [ -z "${bosh_release_src_dir:-}" ]
then
  # Use relative path to the BOSH release
  bosh_release_src_dir=$(readlink -nf $base_dir/../release/src/bosh)
fi

if [ -z "${agent_gem_src_url:-}" ]; then
  mkdir -p $assets_dir/gems
  cp -aL $bosh_release_src_dir/bosh_agent/* $assets_dir/gems
else
  persist_value agent_gem_src_url
fi
